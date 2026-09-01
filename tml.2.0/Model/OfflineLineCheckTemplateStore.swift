import Combine
import Foundation

@MainActor
final class OfflineLineCheckTemplateStore: ObservableObject {
    static let shared = OfflineLineCheckTemplateStore()

    @Published private(set) var cachedLocations: [OfflineLineCheckTemplateCache] = []

    private let storageKey = "offlineLineCheckTemplateCaches"
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        cachedLocations = loadCaches()
    }

    func cachedStations(for locationId: String) -> [Station] {
        cache(for: locationId)?.stations ?? []
    }

    func cachedAt(for locationId: String) -> Date? {
        cache(for: locationId)?.updatedAt
    }

    func cacheStations(_ stations: [Station], locationId: String) {
        var locationCache = cache(for: locationId) ?? OfflineLineCheckTemplateCache(
            locationId: locationId,
            stations: [],
            stationTemplates: [:],
            updatedAt: Date()
        )

        locationCache.stations = stations
        locationCache.updatedAt = Date()
        upsert(locationCache)
    }

    func cacheTemplate(
        from lineCheck: LineCheckDto,
        selectedStationIds: [String],
        availableStations: [Station],
        locationId: String
    ) {
        var locationCache = cache(for: locationId) ?? OfflineLineCheckTemplateCache(
            locationId: locationId,
            stations: availableStations,
            stationTemplates: [:],
            updatedAt: Date()
        )

        locationCache.stations = availableStations

        for station in lineCheck.stations {
            guard let stationId = stationId(
                for: station,
                selectedStationIds: selectedStationIds,
                availableStations: availableStations
            ) else {
                continue
            }

            locationCache.stationTemplates[stationId] = clearedTemplate(from: station)
        }

        locationCache.updatedAt = Date()
        upsert(locationCache)
    }

    func stationIds(for lineCheck: LineCheckDto, locationId: String) -> [String] {
        guard let locationCache = cache(for: locationId) else { return [] }

        return lineCheck.stations.compactMap { lineCheckStation in
            if locationCache.stationTemplates.keys.contains(lineCheckStation.id) {
                return lineCheckStation.id
            }

            if let match = locationCache.stationTemplates.first(where: { _, template in
                template.stationName?.caseInsensitiveCompare(lineCheckStation.stationName ?? "") == .orderedSame
            }) {
                return match.key
            }

            return locationCache.stations.first {
                $0.stationName.caseInsensitiveCompare(lineCheckStation.stationName ?? "") == .orderedSame
            }?.id
        }
    }

    func makeOfflineLineCheck(
        locationId: String,
        selectedStationIds: [String],
        userId: String?,
        username: String?
    ) -> LineCheckDto? {
        guard let locationCache = cache(for: locationId) else { return nil }

        let selectedTemplates = selectedStationIds.compactMap { stationId in
            locationCache.stationTemplates[stationId]
        }

        guard selectedTemplates.count == selectedStationIds.count else { return nil }

        return LineCheckDto(
            id: "offline-\(UUID().uuidString)",
            userId: userId,
            username: username,
            checkTime: Date(),
            completedAt: nil,
            durationSeconds: nil,
            stations: selectedTemplates
        )
    }

    private func stationId(
        for lineCheckStation: LineCheckStationDto,
        selectedStationIds: [String],
        availableStations: [Station]
    ) -> String? {
        if selectedStationIds.contains(lineCheckStation.id) {
            return lineCheckStation.id
        }

        return availableStations.first {
            $0.stationName.caseInsensitiveCompare(lineCheckStation.stationName ?? "") == .orderedSame
        }?.id
    }

    private func clearedTemplate(from station: LineCheckStationDto) -> LineCheckStationDto {
        LineCheckStationDto(
            id: station.id,
            stationName: station.stationName,
            items: station.items.map(clearedTemplateItem)
        )
    }

    private func clearedTemplateItem(_ item: LineCheckItemDto) -> LineCheckItemDto {
        var cleared = item
        cleared.itemChecked = nil
        cleared.temperature = nil
        cleared.observations = ""
        cleared.correctiveNotes = nil
        cleared.correctedBy = nil
        cleared.correctedByName = nil
        cleared.correctedAt = nil
        cleared.isMissing = false
        cleared.isCorrected = false
        cleared.criterionResponses = item.criterionResponses?.map(clearedTemplateCriterion)
        return cleared
    }

    private func clearedTemplateCriterion(
        _ response: LineCheckCriterionResponseDto
    ) -> LineCheckCriterionResponseDto {
        var cleared = response
        cleared.booleanAnswer = nil
        cleared.numberAnswer = nil
        cleared.textAnswer = nil
        cleared.notes = nil
        cleared.requiresCorrection = false
        cleared.photoCount = 0
        return cleared
    }

    private func cache(for locationId: String) -> OfflineLineCheckTemplateCache? {
        cachedLocations.first { $0.locationId == locationId }
    }

    private func upsert(_ cache: OfflineLineCheckTemplateCache) {
        if let index = cachedLocations.firstIndex(where: { $0.locationId == cache.locationId }) {
            cachedLocations[index] = cache
        } else {
            cachedLocations.append(cache)
        }

        saveCaches()
    }

    private func loadCaches() -> [OfflineLineCheckTemplateCache] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }

        do {
            return try JSONDecoder().decode([OfflineLineCheckTemplateCache].self, from: data)
        } catch {
            userDefaults.removeObject(forKey: storageKey)
            return []
        }
    }

    private func saveCaches() {
        do {
            let data = try JSONEncoder().encode(cachedLocations)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            // Template cache failures should not block online line-check creation.
        }
    }
}

struct OfflineLineCheckTemplateCache: Codable {
    let locationId: String
    var stations: [Station]
    var stationTemplates: [String: LineCheckStationDto]
    var updatedAt: Date
}
