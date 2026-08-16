import Foundation

actor AccountSyncCoordinator {
    private let store: AccountLocalStore
    private let remote: any AccountRemote
    private var isSynchronizing = false

    init(store: AccountLocalStore, remote: any AccountRemote) {
        self.store = store
        self.remote = remote
    }

    func synchronize() async {
        guard !isSynchronizing else { return }
        isSynchronizing = true
        defer { isSynchronizing = false }

        while let pending = store.pendingSync(), !pending.operations.isEmpty {
            do {
                let result = try await remote.synchronize(pending.operations)
                guard store.pendingSync()?.userID == pending.userID else { return }
                store.apply(result)
            } catch {
                return
            }
        }
    }
}
