import Foundation

actor AccountSyncCoordinator {
    private let store: AccountLocalStore
    private let client: any ViaAPIClient
    private var isSynchronizing = false

    init(store: AccountLocalStore, client: any ViaAPIClient) {
        self.store = store
        self.client = client
    }

    func synchronize() async {
        guard !isSynchronizing else { return }
        isSynchronizing = true
        defer { isSynchronizing = false }

        while let pending = store.pendingSync(), !pending.operations.isEmpty {
            do {
                let result = try await client.syncAccount(operations: pending.operations)
                guard store.pendingSync()?.userID == pending.userID else { return }
                store.apply(result)
            } catch {
                return
            }
        }
    }
}
