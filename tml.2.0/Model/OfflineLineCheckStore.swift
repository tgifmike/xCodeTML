import Combine
import Foundation

@MainActor
final class OfflineLineCheckStore: ObservableObject {
    static let shared = OfflineLineCheckStore()

    @Published private(set) var pendingSubmissions: [PendingLineCheckSubmission] = []

    private var drafts: [PendingLineCheckSubmission] = []
    private let pendingStorageKey = "pendingLineCheckSubmissions"
    private let draftStorageKey = "offlineLineCheckDrafts"
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        pendingSubmissions = loadSubmissions(forKey: pendingStorageKey)
        drafts = loadSubmissions(forKey: draftStorageKey)
    }

    var pendingCount: Int {
        pendingSubmissions.count
    }

    func pendingCount(for locationId: String) -> Int {
        pendingSubmissions.filter { $0.locationId == locationId }.count
    }

    func registerDraft(
        lineCheck: LineCheckDto,
        locationId: String,
        locationName: String,
        accountName: String,
        userId: String?,
        stationIds: [String]
    ) {
        let draft = PendingLineCheckSubmission(
            lineCheck: lineCheck,
            locationId: locationId,
            locationName: locationName,
            accountName: accountName,
            userId: userId,
            stationIds: stationIds,
            requiresRemoteCreation: true
        )

        upsert(draft, into: &drafts)
        saveSubmissions(drafts, forKey: draftStorageKey)
    }

    func draft(lineCheckId: String) -> PendingLineCheckSubmission? {
        drafts.first { $0.id == lineCheckId }
    }

    func enqueue(
        lineCheck: LineCheckDto,
        locationId: String,
        locationName: String,
        accountName: String
    ) {
        let draft = draft(lineCheckId: lineCheck.id)
        let requiresRemoteCreation = draft?.requiresRemoteCreation == true
        || lineCheck.id.hasPrefix("offline-")

        let pending = PendingLineCheckSubmission(
            lineCheck: lineCheck,
            locationId: locationId,
            locationName: locationName,
            accountName: accountName,
            userId: draft?.userId ?? lineCheck.userId,
            stationIds: draft?.stationIds ?? [],
            requiresRemoteCreation: requiresRemoteCreation
        )

        upsert(pending, into: &pendingSubmissions)
        drafts.removeAll { $0.id == lineCheck.id }
        saveSubmissions(pendingSubmissions, forKey: pendingStorageKey)
        saveSubmissions(drafts, forKey: draftStorageKey)
    }

    func syncPending(locationId: String? = nil) async -> OfflineLineCheckSyncResult {
        var synced = 0
        var failed = 0
        var remaining: [PendingLineCheckSubmission] = []
        var lastErrorMessage: String?

        for pending in pendingSubmissions {
            guard locationId == nil || pending.locationId == locationId else {
                remaining.append(pending)
                continue
            }

            do {
                if shouldCreateRemoteLineCheck(for: pending) {
                    try await createAndSaveRemoteLineCheck(for: pending)
                } else {
                    _ = try await LineCheckApi.shared.saveLineCheck(pending.lineCheck)
                    _ = await OfflineLineCheckPhotoStore.shared.syncPending(
                        lineCheckId: pending.lineCheck.id,
                        locationId: pending.locationId
                    )
                }

                synced += 1
            } catch {
                failed += 1
                remaining.append(pending)
                lastErrorMessage = error.localizedDescription
            }
        }

        pendingSubmissions = remaining
        saveSubmissions(pendingSubmissions, forKey: pendingStorageKey)

        return OfflineLineCheckSyncResult(
            synced: synced,
            failed: failed,
            lastErrorMessage: lastErrorMessage
        )
    }

    func remove(id: String) {
        pendingSubmissions.removeAll { $0.id == id }
        saveSubmissions(pendingSubmissions, forKey: pendingStorageKey)
    }

    private func shouldCreateRemoteLineCheck(for pending: PendingLineCheckSubmission) -> Bool {
        pending.requiresRemoteCreation || pending.lineCheck.id.hasPrefix("offline-")
    }

    private func resolvedStationIds(for pending: PendingLineCheckSubmission) -> [String] {
        if !pending.stationIds.isEmpty {
            return pending.stationIds
        }

        return OfflineLineCheckTemplateStore.shared.stationIds(
            for: pending.lineCheck,
            locationId: pending.locationId
        )
    }

    private func createAndSaveRemoteLineCheck(
        for pending: PendingLineCheckSubmission
    ) async throws {
        let userId = pending.userId ?? pending.lineCheck.userId
        let stationIds = resolvedStationIds(for: pending)

        guard let userId, !userId.isEmpty, !stationIds.isEmpty else {
            throw OfflineLineCheckStoreError.missingCreationMetadata(
                hasUserId: userId?.isEmpty == false,
                stationCount: stationIds.count
            )
        }

        let created = try await LineCheckApi.shared.createLineCheck(
            userId: userId,
            stationIds: stationIds
        )
        let merged = mergedLineCheck(remote: created, local: pending.lineCheck)
        let saved = try await LineCheckApi.shared.saveLineCheck(merged)
        _ = await OfflineLineCheckPhotoStore.shared.syncPending(
            lineCheckId: pending.lineCheck.id,
            locationId: pending.locationId,
            remoteLineCheck: saved
        )
    }

    private func mergedLineCheck(remote: LineCheckDto, local: LineCheckDto) -> LineCheckDto {
        var merged = remote

        merged.stations = remote.stations.map { remoteStation in
            guard let localStation = matchingStation(for: remoteStation, in: local.stations) else {
                return remoteStation
            }

            return LineCheckStationDto(
                id: remoteStation.id,
                stationName: remoteStation.stationName,
                items: remoteStation.items.map { remoteItem in
                    guard let localItem = matchingItem(for: remoteItem, in: localStation.items) else {
                        return remoteItem
                    }

                    return mergedItem(remote: remoteItem, local: localItem)
                }
            )
        }

        return merged
    }

    private func mergedItem(remote: LineCheckItemDto, local: LineCheckItemDto) -> LineCheckItemDto {
        var merged = remote
        merged.itemChecked = local.itemChecked
        merged.temperature = local.temperature
        merged.observations = local.observations
        merged.correctiveNotes = local.correctiveNotes
        merged.isMissing = local.isMissing
        merged.isCorrected = local.isCorrected
        merged.criterionResponses = mergedCriterionResponses(
            remote: remote.criterionResponses,
            local: local.criterionResponses
        )
        return merged
    }

    private func mergedCriterionResponses(
        remote: [LineCheckCriterionResponseDto]?,
        local: [LineCheckCriterionResponseDto]?
    ) -> [LineCheckCriterionResponseDto]? {
        guard let remote else { return nil }

        return remote.map { remoteResponse in
            guard let localResponse = matchingCriterion(for: remoteResponse, in: local ?? []) else {
                return remoteResponse
            }

            var merged = remoteResponse
            merged.booleanAnswer = localResponse.booleanAnswer
            merged.numberAnswer = localResponse.numberAnswer
            merged.textAnswer = localResponse.textAnswer
            merged.notes = localResponse.notes
            merged.requiresCorrection = localResponse.requiresCorrection
            merged.photoCount = localResponse.photoCount
            return merged
        }
    }

    private func matchingStation(
        for station: LineCheckStationDto,
        in stations: [LineCheckStationDto]
    ) -> LineCheckStationDto? {
        stations.first { $0.id == station.id }
        ?? stations.first {
            ($0.stationName ?? "").caseInsensitiveCompare(station.stationName ?? "") == .orderedSame
        }
    }

    private func matchingItem(
        for item: LineCheckItemDto,
        in items: [LineCheckItemDto]
    ) -> LineCheckItemDto? {
        if let itemId = item.id,
           let match = items.first(where: { $0.id == itemId }) {
            return match
        }

        return items.first {
            ($0.itemName ?? "").caseInsensitiveCompare(item.itemName ?? "") == .orderedSame
        }
    }

    private func matchingCriterion(
        for response: LineCheckCriterionResponseDto,
        in responses: [LineCheckCriterionResponseDto]
    ) -> LineCheckCriterionResponseDto? {
        if let criterionId = response.itemCriterionId ?? response.criterionId,
           let match = responses.first(where: {
               ($0.itemCriterionId ?? $0.criterionId) == criterionId
           }) {
            return match
        }

        return responses.first {
            ($0.label ?? $0.criterionName ?? "").caseInsensitiveCompare(
                response.label ?? response.criterionName ?? ""
            ) == .orderedSame
        }
    }

    private func upsert(
        _ submission: PendingLineCheckSubmission,
        into submissions: inout [PendingLineCheckSubmission]
    ) {
        if let index = submissions.firstIndex(where: { $0.id == submission.id }) {
            submissions[index] = submission
        } else {
            submissions.append(submission)
        }
    }

    private func loadSubmissions(forKey key: String) -> [PendingLineCheckSubmission] {
        guard let data = userDefaults.data(forKey: key) else { return [] }

        do {
            return try JSONDecoder().decode([PendingLineCheckSubmission].self, from: data)
        } catch {
            userDefaults.removeObject(forKey: key)
            return []
        }
    }

    private func saveSubmissions(
        _ submissions: [PendingLineCheckSubmission],
        forKey key: String
    ) {
        do {
            let data = try JSONEncoder().encode(submissions)
            userDefaults.set(data, forKey: key)
        } catch {
            // Offline persistence failures should not crash line-check entry.
        }
    }
}

struct OfflineLineCheckSyncResult {
    let synced: Int
    let failed: Int
    let lastErrorMessage: String?
}

enum OfflineLineCheckStoreError: LocalizedError {
    case missingCreationMetadata(hasUserId: Bool, stationCount: Int)

    var errorDescription: String? {
        switch self {
        case .missingCreationMetadata(let hasUserId, let stationCount):
            var missing: [String] = []

            if !hasUserId {
                missing.append("user")
            }

            if stationCount == 0 {
                missing.append("station")
            }

            return "Offline line check is missing \(missing.joined(separator: " and ")) data needed to sync."
        }
    }
}
