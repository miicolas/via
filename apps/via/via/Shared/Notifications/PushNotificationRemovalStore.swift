import Foundation

struct PushNotificationPendingRemovals: Codable, Equatable, Sendable {
    var unregisterDevice = false
    var journeyIDs: Set<String> = []

    var isEmpty: Bool {
        !unregisterDevice && journeyIDs.isEmpty
    }
}

protocol PushNotificationRemovalStoring: Sendable {
    func load() async throws -> PushNotificationPendingRemovals
    func save(_ removals: PushNotificationPendingRemovals) async throws
}

actor LocalPushNotificationRemovalStore: PushNotificationRemovalStoring {
    private struct Snapshot: Codable {
        let revision: UInt64
        let removals: PushNotificationPendingRemovals
    }

    private static let fallbackKey = "via.push.pending-removals.v1"
    private let file: LocalJSONFile
    private let defaults: UserDefaults

    init(fileURL: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        file = fileURL.map(LocalJSONFile.init(url:))
            ?? LocalJSONFile(name: "push-notification-removals.json")
    }

    func load() throws -> PushNotificationPendingRemovals {
        var snapshots: [Snapshot] = []
        var foundCorruption = false
        do {
            if let data = try file.read() {
                snapshots.append(try decodeSnapshot(data))
            }
        } catch {
            foundCorruption = true
        }
        if let fallback = defaults.data(forKey: Self.fallbackKey) {
            do {
                snapshots.append(try decodeSnapshot(fallback))
            } catch {
                foundCorruption = true
            }
        }
        let newestRevision = snapshots.map(\.revision).max()
        var merged = snapshots
            .filter { $0.revision == newestRevision }
            .map(\.removals)
            .reduce(into: PushNotificationPendingRemovals()) { result, stored in
                result.unregisterDevice = result.unregisterDevice || stored.unregisterDevice
                result.journeyIDs.formUnion(stored.journeyIDs)
            }
        if foundCorruption {
            // An unreadable copy may have contained removals absent from the
            // surviving copy. Fail closed by resetting the whole installation.
            merged.unregisterDevice = true
        }
        return merged
    }

    func save(_ removals: PushNotificationPendingRemovals) throws {
        let revision = try nextRevision()
        let data = try JSONEncoder.via.encode(Snapshot(revision: revision, removals: removals))
        // Write the newer snapshot to the redundant journal first. If file
        // compaction fails, load() still chooses this revision over stale disk state.
        defaults.set(data, forKey: Self.fallbackKey)
        if removals.isEmpty {
            try file.remove()
            defaults.removeObject(forKey: Self.fallbackKey)
            return
        }
        do {
            try file.write(data)
            defaults.removeObject(forKey: Self.fallbackKey)
        } catch {
            // Application Support can be temporarily unavailable while the
            // device is locked or out of space. UserDefaults is a redundant
            // safety journal so a failed network removal still survives relaunch.
            defaults.set(data, forKey: Self.fallbackKey)
        }
    }

    private func nextRevision() throws -> UInt64 {
        var revisions: [UInt64] = []
        if let data = try? file.read(), let snapshot = try? decodeSnapshot(data) {
            revisions.append(snapshot.revision)
        }
        if let fallback = defaults.data(forKey: Self.fallbackKey) {
            if let snapshot = try? decodeSnapshot(fallback) {
                revisions.append(snapshot.revision)
            }
        }
        return (revisions.max() ?? 0) + 1
    }

    private func decodeSnapshot(_ data: Data) throws -> Snapshot {
        if let snapshot = try? JSONDecoder.via.decode(Snapshot.self, from: data) {
            return snapshot
        }
        return Snapshot(
            revision: 0,
            removals: try JSONDecoder.via.decode(PushNotificationPendingRemovals.self, from: data)
        )
    }
}

actor InMemoryPushNotificationRemovalStore: PushNotificationRemovalStoring {
    private var removals: PushNotificationPendingRemovals

    init(removals: PushNotificationPendingRemovals = PushNotificationPendingRemovals()) {
        self.removals = removals
    }

    func load() -> PushNotificationPendingRemovals { removals }

    func save(_ removals: PushNotificationPendingRemovals) {
        self.removals = removals
    }
}
