import Foundation
import XCTest
@testable import Via

@MainActor
final class PushNotificationTests: XCTestCase {
    func testAPNsTokensUseLowercaseHexWithoutSeparators() {
        XCTAssertEqual(
            PushNotificationManager.hexToken(Data([0x00, 0x0F, 0xA0, 0xFF])),
            "000fa0ff"
        )
    }

    func testFailedJourneyRemovalIsReplayedAfterManagerReconstruction() async throws {
        let store = InMemoryPushNotificationRemovalStore(
            removals: PushNotificationPendingRemovals(journeyIDs: ["journey-1"])
        )
        let failingRemote = FakePushNotificationRemote(failJourneyRemoval: true)
        let first = makeManager(store: store, remote: failingRemote)
        await first.registerForAuthenticatedSession()
        await first.setNotificationsAuthorized(true)
        let failedAttempts = await failingRemote.unregisteredJourneyIDs
        XCTAssertEqual(failedAttempts, ["journey-1"])

        let succeedingRemote = FakePushNotificationRemote()
        let restored = makeManager(store: store, remote: succeedingRemote)
        await restored.registerForAuthenticatedSession()
        await restored.setNotificationsAuthorized(true)

        let replayed = await succeedingRemote.unregisteredJourneyIDs
        let pending = try await store.load()
        XCTAssertEqual(replayed, ["journey-1"])
        XCTAssertTrue(pending.isEmpty)
    }

    func testUnreadableRemovalOutboxConservativelyUnregistersDevice() async {
        let store = UnreadablePushNotificationRemovalStore()
        let remote = FakePushNotificationRemote()
        let manager = makeManager(store: store, remote: remote)

        await manager.registerForAuthenticatedSession()

        let installations = await remote.unregisteredInstallationIDs
        XCTAssertEqual(installations, ["installation-1"])
    }

    func testRemovalStoreMergesFallbackJournalWithOlderFile() async throws {
        let suiteName = "PushNotificationTests.\(UUID().uuidString)"
        nonisolated(unsafe) let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "removals.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalPushNotificationRemovalStore(
            fileURL: fileURL,
            defaults: defaults
        )
        try await store.save(
            PushNotificationPendingRemovals(journeyIDs: ["journey-a"])
        )
        defaults.set(
            try JSONEncoder().encode(
                TestPushNotificationRemovalSnapshot(
                    revision: 2,
                    removals: PushNotificationPendingRemovals(
                        unregisterDevice: true,
                        journeyIDs: ["journey-a", "journey-b"]
                    )
                )
            ),
            forKey: "via.push.pending-removals.v1"
        )

        let merged = try await store.load()

        XCTAssertTrue(merged.unregisterDevice)
        XCTAssertEqual(merged.journeyIDs, ["journey-a", "journey-b"])
    }

    func testNewerEmptyFallbackDoesNotResurrectRemovalFromStaleFile() async throws {
        let suiteName = "PushNotificationTests.\(UUID().uuidString)"
        nonisolated(unsafe) let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "removals.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalPushNotificationRemovalStore(
            fileURL: fileURL,
            defaults: defaults
        )
        try await store.save(
            PushNotificationPendingRemovals(journeyIDs: ["journey-reused"])
        )
        defaults.set(
            try JSONEncoder().encode(
                TestPushNotificationRemovalSnapshot(
                    revision: 2,
                    removals: PushNotificationPendingRemovals()
                )
            ),
            forKey: "via.push.pending-removals.v1"
        )

        let restored = try await store.load()

        XCTAssertTrue(restored.isEmpty)
    }

    func testCorruptRemovalFileFailsClosedAndCanBeOverwritten() async throws {
        let suiteName = "PushNotificationTests.\(UUID().uuidString)"
        nonisolated(unsafe) let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "removals.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalPushNotificationRemovalStore(
            fileURL: fileURL,
            defaults: defaults
        )

        let recovered = try await store.load()
        try await store.save(recovered)
        let persisted = try await store.load()

        XCTAssertTrue(recovered.unregisterDevice)
        XCTAssertTrue(persisted.unregisterDevice)
    }

    private func makeManager(
        store: any PushNotificationRemovalStoring,
        remote: any PushNotificationRemote
    ) -> PushNotificationManager {
        let manager = PushNotificationManager(
            installationID: "installation-1",
            removalStore: store
        )
        manager.configure(
            configuration: AppConfiguration(
                apiBaseURL: URL(string: "https://api.example.com")!,
                bundleIdentifier: "dev.via.app",
                apnsEnvironment: .sandbox
            ),
            remote: remote
        )
        return manager
    }
}

private actor FakePushNotificationRemote: PushNotificationRemote {
    private let failJourneyRemoval: Bool
    private(set) var unregisteredJourneyIDs: [String] = []
    private(set) var unregisteredInstallationIDs: [String] = []

    init(failJourneyRemoval: Bool = false) {
        self.failJourneyRemoval = failJourneyRemoval
    }

    func registerDevice(_ registration: PushDeviceRegistration) {}

    func unregisterDevice(installationID: String) {
        unregisteredInstallationIDs.append(installationID)
    }

    func registerActiveJourney(_ registration: PushActiveJourneyRegistration) {}

    func unregisterActiveJourney(installationID: String, journeyID: String) throws {
        unregisteredJourneyIDs.append(journeyID)
        if failJourneyRemoval { throw FakePushNotificationRemoteError.failed }
    }
}

private actor UnreadablePushNotificationRemovalStore: PushNotificationRemovalStoring {
    private var recovered: PushNotificationPendingRemovals?

    func load() throws -> PushNotificationPendingRemovals {
        if let recovered { return recovered }
        throw FakePushNotificationRemoteError.failed
    }

    func save(_ removals: PushNotificationPendingRemovals) {
        recovered = removals
    }
}

private enum FakePushNotificationRemoteError: Error {
    case failed
}

private struct TestPushNotificationRemovalSnapshot: Codable {
    let revision: UInt64
    let removals: PushNotificationPendingRemovals
}
