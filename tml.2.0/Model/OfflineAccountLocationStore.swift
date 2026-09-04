import Combine
import Foundation

@MainActor
final class OfflineAccountLocationStore: ObservableObject {
    static let shared = OfflineAccountLocationStore()

    @Published private(set) var accountCaches: [OfflineAccountCache] = []
    @Published private(set) var locationCaches: [OfflineLocationCache] = []

    private let accountStorageKey = "offlineAccountCaches"
    private let locationStorageKey = "offlineLocationCaches"
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        accountCaches = loadAccountCaches()
        locationCaches = loadLocationCaches()
    }

    func cachedAccounts(for userId: String) -> [Account] {
        accountCache(for: userId)?.accounts ?? []
    }

    func cachedAccountsAt(for userId: String) -> Date? {
        accountCache(for: userId)?.updatedAt
    }

    func cachedAccount(id: String) -> Account? {
        accountCaches
            .flatMap(\.accounts)
            .first { $0.id == id }
    }

    func cacheAccounts(_ accounts: [Account], userId: String) {
        let cache = OfflineAccountCache(
            userId: userId,
            accounts: accounts,
            updatedAt: Date()
        )

        if let index = accountCaches.firstIndex(where: { $0.userId == userId }) {
            accountCaches[index] = cache
        } else {
            accountCaches.append(cache)
        }

        saveCaches(accountCaches, forKey: accountStorageKey)
    }

    func cachedLocations(for accountId: String) -> [Location] {
        locationCache(for: accountId)?.locations ?? []
    }

    func cachedLocationsAt(for accountId: String) -> Date? {
        locationCache(for: accountId)?.updatedAt
    }

    func cachedLocation(id: String, accountId: String) -> Location? {
        locationCache(for: accountId)?.locations.first { $0.id == id }
    }

    func cacheLocations(_ locations: [Location], accountId: String) {
        let cache = OfflineLocationCache(
            accountId: accountId,
            locations: locations,
            updatedAt: Date()
        )

        if let index = locationCaches.firstIndex(where: { $0.accountId == accountId }) {
            locationCaches[index] = cache
        } else {
            locationCaches.append(cache)
        }

        saveCaches(locationCaches, forKey: locationStorageKey)
    }

    private func accountCache(for userId: String) -> OfflineAccountCache? {
        accountCaches.first { $0.userId == userId }
    }

    private func locationCache(for accountId: String) -> OfflineLocationCache? {
        locationCaches.first { $0.accountId == accountId }
    }

    private func loadAccountCaches() -> [OfflineAccountCache] {
        guard let data = userDefaults.data(forKey: accountStorageKey) else { return [] }

        do {
            return try JSONDecoder().decode([OfflineAccountCache].self, from: data)
        } catch {
            userDefaults.removeObject(forKey: accountStorageKey)
            return []
        }
    }

    private func loadLocationCaches() -> [OfflineLocationCache] {
        guard let data = userDefaults.data(forKey: locationStorageKey) else { return [] }

        do {
            return try JSONDecoder().decode([OfflineLocationCache].self, from: data)
        } catch {
            userDefaults.removeObject(forKey: locationStorageKey)
            return []
        }
    }

    private func saveCaches<T: Encodable>(_ caches: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(caches)
            userDefaults.set(data, forKey: key)
        } catch {
            // Offline navigation cache failures should not block normal online use.
        }
    }
}

struct OfflineAccountCache: Codable {
    let userId: String
    var accounts: [Account]
    var updatedAt: Date
}

struct OfflineLocationCache: Codable {
    let accountId: String
    var locations: [Location]
    var updatedAt: Date
}
