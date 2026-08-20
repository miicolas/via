import Foundation
import XCTest
@testable import Via

final class ProfileModelTests: XCTestCase {
    @MainActor
    func testProfilesRemainIsolatedByScopeAndSeedOnlyEmptyProfiles() {
        let store = InMemoryProfileStore()
        let model = ProfileModel(store: store, now: { Date(timeIntervalSince1970: 100) })

        model.activate(scope: .user("alex"), seedName: "Nom Apple")
        XCTAssertEqual(model.displayName, "Nom Apple")
        model.draftName = "Alex"
        model.setAvatarData(Data([1, 2, 3]))
        XCTAssertTrue(model.saveEditing())

        model.activate(scope: .user("sam"), seedName: "Sam Apple")
        XCTAssertEqual(model.displayName, "Sam Apple")
        XCTAssertNil(model.avatarData)
        model.draftName = "Sam"
        XCTAssertTrue(model.saveEditing())

        model.activate(scope: .user("alex"), seedName: "Autre nom Apple")
        XCTAssertEqual(model.displayName, "Alex")
        XCTAssertEqual(model.avatarData, Data([1, 2, 3]))
    }

    @MainActor
    func testBlankNameIsRejectedAndDiscardRestoresSnapshot() {
        let model = ProfileModel(store: InMemoryProfileStore())
        model.activate(scope: .anonymous, seedName: "Alice")

        model.draftName = "  \n "
        XCTAssertFalse(model.canSaveDraft)
        XCTAssertFalse(model.saveEditing())

        model.draftName = "Bob"
        model.setAvatarData(Data([9]))
        model.discardEditing()

        XCTAssertEqual(model.draftName, "Alice")
        XCTAssertNil(model.draftAvatarData)
    }

    @MainActor
    func testContactWithoutPhotoKeepsPreviousAvatar() {
        let avatar = Data([7, 8, 9])
        let store = InMemoryProfileStore(snapshots: [
            .anonymous: ProfileSnapshot(
                displayName: "Alice",
                avatarData: avatar,
                updatedAt: .distantPast
            )
        ])
        let model = ProfileModel(store: store)
        model.activate(scope: .anonymous)

        model.importContact(ProfileContact(displayName: "Sam Lee", avatarData: nil))

        XCTAssertEqual(model.draftName, "Sam Lee")
        XCTAssertEqual(model.draftAvatarData, avatar)
    }

    @MainActor
    func testSaveFailureLeavesSnapshotUntouchedAndExposesError() {
        let model = ProfileModel(store: FailingProfileStore())
        model.activate(scope: .anonymous, seedName: "Alice")
        model.draftName = "Bob"

        XCTAssertFalse(model.saveEditing())
        XCTAssertEqual(model.displayName, "Alice")
        XCTAssertNotNil(model.errorMessage)
    }

    func testLocalStoreErasesMetadataAndAvatarFile() throws {
        let suiteName = "dev.via.profile-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ViaProfileTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: directory)
        }

        let store = LocalProfileStore(defaults: defaults, directoryURL: directory)
        let snapshot = ProfileSnapshot(
            displayName: "Alex",
            avatarData: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        try store.save(snapshot, scope: .user("alex"))

        XCTAssertEqual(try store.load(scope: .user("alex")), snapshot)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)

        try store.erase(scope: .user("alex"))

        XCTAssertNil(try store.load(scope: .user("alex")))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testInitialsUseAtMostTwoWords() {
        XCTAssertEqual(
            ProfileSnapshot(
                displayName: "  Alex de Paris ",
                avatarData: nil,
                updatedAt: .distantPast
            ).initials,
            "AD"
        )
        XCTAssertNil(ProfileSnapshot.empty.initials)
    }
}

private final class FailingProfileStore: ProfileStoring, @unchecked Sendable {
    func load(scope: ProfileScope) throws -> ProfileSnapshot? { nil }
    func save(_ snapshot: ProfileSnapshot, scope: ProfileScope) throws {
        throw CocoaError(.fileWriteUnknown)
    }
    func erase(scope: ProfileScope) throws {}
    func eraseAll() throws {}
}
