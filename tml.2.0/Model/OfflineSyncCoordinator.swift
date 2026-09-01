import Combine
import Foundation
import Network

@MainActor
final class OfflineSyncCoordinator: ObservableObject {
    static let shared = OfflineSyncCoordinator()

    @Published private(set) var isOnline = true
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncAttemptAt: Date?
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastSyncSummary: String?

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "tml.offline-sync-monitor")
    private var hasStartedMonitoring = false
    private var periodicSyncTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private let lastSyncAtKey = "offlineSyncLastSyncAt"

    #if DEBUG
    private let periodicSyncIntervalSeconds: UInt64 = 30
    #else
    private let periodicSyncIntervalSeconds: UInt64 = 15 * 60
    #endif

    private init() {
        lastSyncAt = UserDefaults.standard.object(forKey: lastSyncAtKey) as? Date
        observeOfflineStores()
    }

    var pendingLineCheckCount: Int {
        OfflineLineCheckStore.shared.pendingCount
    }

    var pendingPhotoCount: Int {
        OfflineLineCheckPhotoStore.shared.pendingCount
    }

    var pendingCount: Int {
        pendingLineCheckCount + pendingPhotoCount
    }

    private func observeOfflineStores() {
        OfflineLineCheckStore.shared.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)

        OfflineLineCheckPhotoStore.shared.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    var statusText: String {
        if isSyncing {
            return "Syncing offline work..."
        }

        if pendingCount == 0 {
            return "No offline work waiting to sync."
        }

        if isOnline {
            return "\(pendingCount) offline item(s) waiting to sync."
        }

        return "Offline. \(pendingCount) item(s) saved on this device."
    }

    func startMonitoring() {
        guard !hasStartedMonitoring else { return }
        hasStartedMonitoring = true

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }

                let wasOnline = self.isOnline
                self.isOnline = path.status == .satisfied

                if self.isOnline && !wasOnline {
                    await self.syncIfPossible(reason: "network-restored")
                }
            }
        }

        monitor.start(queue: monitorQueue)
        startPeriodicSync()
    }

    func syncIfPossible(reason: String) async {
        #if DEBUG
        print("Offline sync check [\(reason)] online=\(isOnline) pending=\(pendingCount) syncing=\(isSyncing)")
        #endif

        guard isOnline else { return }
        await syncNow()
    }

    private func startPeriodicSync() {
        periodicSyncTask?.cancel()

        periodicSyncTask = Task { [weak self] in
            guard let self else { return }

            await self.syncIfPossible(reason: "periodic-start")

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(self.periodicSyncIntervalSeconds))
                } catch {
                    return
                }

                await self.syncIfPossible(reason: "periodic-timer")
            }
        }
    }

    func syncNow() async {
        lastSyncAttemptAt = Date()

        guard !isSyncing, pendingCount > 0 else { return }

        isSyncing = true
        lastErrorMessage = nil

        let lineCheckResult = await OfflineLineCheckStore.shared.syncPending()
        let photoResult = await OfflineLineCheckPhotoStore.shared.syncPending()

        let syncedCount = lineCheckResult.synced + photoResult.synced
        let failedCount = lineCheckResult.failed + photoResult.failed

        if failedCount == 0 {
            lastSyncSummary = "Synced \(syncedCount) offline item(s)."
            lastErrorMessage = nil
        } else if syncedCount > 0 {
            lastSyncSummary = "Synced \(syncedCount) offline item(s). \(failedCount) still waiting."
            lastErrorMessage = lineCheckResult.lastErrorMessage ?? photoResult.lastErrorMessage
        } else {
            lastSyncSummary = nil
            lastErrorMessage = lineCheckResult.lastErrorMessage
            ?? photoResult.lastErrorMessage
            ?? "Could not sync offline work."
        }

        #if DEBUG
        print("Offline sync result synced=\(syncedCount) failed=\(failedCount) pending=\(pendingCount) error=\(lastErrorMessage ?? "none")")
        #endif

        lastSyncAt = Date()
        UserDefaults.standard.set(lastSyncAt, forKey: lastSyncAtKey)
        isSyncing = false
    }
}
