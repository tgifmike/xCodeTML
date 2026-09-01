import Combine
import Foundation

@MainActor
final class OfflineLineCheckPhotoStore: ObservableObject {
    static let shared = OfflineLineCheckPhotoStore()

    @Published private(set) var pendingPhotos: [PendingLineCheckPhoto] = []

    private let storageKey = "pendingLineCheckPhotos"
    private let directoryName = "PendingLineCheckPhotos"
    private let userDefaults: UserDefaults
    private let fileManager: FileManager

    private init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        pendingPhotos = loadPendingPhotos()
    }

    var pendingCount: Int {
        pendingPhotos.count
    }

    func pendingCount(for lineCheckIds: Set<String>) -> Int {
        pendingPhotos.filter { lineCheckIds.contains($0.localLineCheckId) }.count
    }

    func pendingCount(forLocationId locationId: String) -> Int {
        pendingPhotos.filter { $0.locationId == locationId }.count
    }

    func pendingDtos(
        lineCheckId: String,
        itemId: String?,
        itemName: String
    ) -> [LineCheckPhotoDto] {
        pendingPhotos
            .filter {
                $0.localLineCheckId == lineCheckId
                && ($0.lineCheckItemId == itemId || $0.itemName == itemName)
            }
            .map { pending in
                dto(from: pending)
            }
    }

    func enqueue(
        lineCheckId: String,
        locationId: String,
        lineCheckItemId: String?,
        stationName: String,
        itemName: String,
        criterionResponseId: String?,
        criterionLabel: String?,
        imageData: Data,
        fileName: String,
        photoType: LineCheckPhotoType,
        notes: String?
    ) throws -> LineCheckPhotoDto {
        let id = "pending-photo-\(UUID().uuidString)"
        let storedFileName = "\(id).jpg"
        let relativePath = "\(directoryName)/\(storedFileName)"
        let fileURL = try pendingPhotoDirectory().appendingPathComponent(storedFileName)
        try imageData.write(to: fileURL, options: [.atomic])

        let pending = PendingLineCheckPhoto(
            id: id,
            localLineCheckId: lineCheckId,
            locationId: locationId,
            lineCheckItemId: lineCheckItemId,
            stationName: stationName,
            itemName: itemName,
            criterionResponseId: criterionResponseId,
            criterionLabel: criterionLabel,
            photoType: photoType,
            notes: notes,
            fileName: fileName,
            relativeFilePath: relativePath,
            createdAt: Date()
        )

        pendingPhotos.append(pending)
        savePendingPhotos()
        return dto(from: pending)
    }

    func syncPending(
        lineCheckId: String? = nil,
        locationId: String? = nil,
        remoteLineCheck: LineCheckDto? = nil
    ) async -> OfflineLineCheckPhotoSyncResult {
        var synced = 0
        var failed = 0
        var remaining: [PendingLineCheckPhoto] = []
        var lastErrorMessage: String?

        for pending in pendingPhotos {
            guard lineCheckId == nil || pending.localLineCheckId == lineCheckId else {
                remaining.append(pending)
                continue
            }

            guard locationId == nil || pending.locationId == locationId else {
                remaining.append(pending)
                continue
            }

            do {
                try await upload(pending, remoteLineCheck: remoteLineCheck)
                try? fileManager.removeItem(at: fileURL(for: pending))
                synced += 1
            } catch {
                failed += 1
                remaining.append(pending)
                lastErrorMessage = error.localizedDescription
            }
        }

        pendingPhotos = remaining
        savePendingPhotos()

        return OfflineLineCheckPhotoSyncResult(
            synced: synced,
            failed: failed,
            lastErrorMessage: lastErrorMessage
        )
    }

    private func upload(
        _ pending: PendingLineCheckPhoto,
        remoteLineCheck: LineCheckDto?
    ) async throws {
        let resolved = resolve(pending, remoteLineCheck: remoteLineCheck)
        let imageData = try Data(contentsOf: fileURL(for: pending))

        _ = try await LineCheckPhotoApi.shared.uploadPhoto(
            lineCheckItemId: resolved.itemId,
            imageData: imageData,
            fileName: pending.fileName,
            photoType: pending.photoType,
            notes: pending.notes,
            criterionResponseId: resolved.criterionResponseId
        )
    }

    private func resolve(
        _ pending: PendingLineCheckPhoto,
        remoteLineCheck: LineCheckDto?
    ) -> ResolvedPhotoTarget {
        guard let remoteLineCheck else {
            return ResolvedPhotoTarget(
                itemId: pending.lineCheckItemId ?? "",
                criterionResponseId: pending.criterionResponseId
            )
        }

        guard let station = remoteLineCheck.stations.first(where: {
            ($0.stationName ?? "").caseInsensitiveCompare(pending.stationName) == .orderedSame
        }),
              let item = station.items.first(where: {
                  ($0.itemName ?? "").caseInsensitiveCompare(pending.itemName) == .orderedSame
              }),
              let itemId = item.id else {
            return ResolvedPhotoTarget(
                itemId: pending.lineCheckItemId ?? "",
                criterionResponseId: pending.criterionResponseId
            )
        }

        let criterionResponseId: String?
        if pending.photoType == .criterion {
            criterionResponseId = item.criterionResponses?.first(where: { response in
                if let criterionLabel = pending.criterionLabel,
                   (response.label ?? response.criterionName ?? "").caseInsensitiveCompare(criterionLabel) == .orderedSame {
                    return true
                }

                return (response.id == pending.criterionResponseId)
                || ((response.itemCriterionId ?? response.criterionId) == pending.criterionResponseId)
            })?.id
        } else {
            criterionResponseId = nil
        }

        return ResolvedPhotoTarget(
            itemId: itemId,
            criterionResponseId: criterionResponseId
        )
    }

    private func dto(_ pending: PendingLineCheckPhoto) -> LineCheckPhotoDto {
        dto(from: pending)
    }

    private func dto(from pending: PendingLineCheckPhoto) -> LineCheckPhotoDto {
        LineCheckPhotoDto(
            id: pending.id,
            s3Key: nil,
            originalFileName: pending.fileName,
            contentType: "image/jpeg",
            photoType: pending.photoType,
            notes: pending.notes,
            createdAt: pending.createdAt,
            createdBy: nil,
            url: fileURL(for: pending).absoluteString
        )
    }

    private func fileURL(for pending: PendingLineCheckPhoto) -> URL {
        applicationSupportDirectory()
            .appendingPathComponent(pending.relativeFilePath)
    }

    private func pendingPhotoDirectory() throws -> URL {
        let directory = applicationSupportDirectory().appendingPathComponent(directoryName)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func applicationSupportDirectory() -> URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls[0]
    }

    private func loadPendingPhotos() -> [PendingLineCheckPhoto] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }

        do {
            return try JSONDecoder().decode([PendingLineCheckPhoto].self, from: data)
        } catch {
            userDefaults.removeObject(forKey: storageKey)
            return []
        }
    }

    private func savePendingPhotos() {
        do {
            let data = try JSONEncoder().encode(pendingPhotos)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            // Photo queue failures should not crash line-check entry.
        }
    }
}

struct OfflineLineCheckPhotoSyncResult {
    let synced: Int
    let failed: Int
    let lastErrorMessage: String?
}

private struct ResolvedPhotoTarget {
    let itemId: String
    let criterionResponseId: String?
}
