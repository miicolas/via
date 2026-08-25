import XCTest
@testable import Via

final class SavedDestinationEditingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "dev.via.saved-destination-editing-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testPlaceContextOnAFreshAccountStartsANewPinnedDraft() {
        let model = makeModel()

        let draft = SavedDestinationEditing.draft(
            for: addressResult(id: "a"),
            context: .place(.home),
            in: model
        )

        guard case .place(let role, let existing) = draft.target else {
            return XCTFail("Expected a pinned place target, got \(draft.target)")
        }
        XCTAssertEqual(role, .home)
        XCTAssertNil(existing)
        XCTAssertTrue(draft.isNew)
        XCTAssertEqual(draft.label, "Maison")
        XCTAssertEqual(draft.systemImage, SavedPlace.Role.home.systemImage)
    }

    @MainActor
    func testAddressAlreadySavedAsADestinationReopensThatDestination() {
        let model = makeModel()
        let result = addressResult(id: "a")
        model.saveDestination(result, label: "Salle de sport", systemImage: "dumbbell.fill")

        let draft = SavedDestinationEditing.draft(
            for: result,
            context: .place(.home),
            in: model
        )

        // The dedupe wins over the requested role: saving the same address
        // twice under two names is never what the tap meant.
        XCTAssertEqual(draft.existingDestination?.label, "Salle de sport")
        XCTAssertEqual(draft.label, "Salle de sport")
        XCTAssertFalse(draft.isNew)
    }

    @MainActor
    func testAddressAlreadyPinnedReopensThatPlace() {
        let model = makeModel()
        let result = addressResult(id: "a")
        model.setPlace(result, role: .work)

        let draft = SavedDestinationEditing.draft(
            for: result,
            context: .destination,
            in: model
        )

        XCTAssertEqual(draft.role, .work)
        XCTAssertFalse(draft.isNew)
    }

    @MainActor
    func testReplacementKeepsLabelAndSymbolAndSwapsOnlyTheResult() {
        let model = makeModel()
        let original = SavedDestinationDraft(
            target: .destination(existing: nil),
            result: addressResult(id: "a"),
            label: "Chez Léa",
            systemImage: "heart.fill"
        )
        let replacement = addressResult(id: "b")

        let draft = SavedDestinationEditing.draft(
            for: replacement,
            context: .replacement(original),
            in: model
        )

        XCTAssertEqual(draft.label, "Chez Léa")
        XCTAssertEqual(draft.systemImage, "heart.fill")
        XCTAssertEqual(draft.result.id, replacement.id)
    }

    @MainActor
    func testReplacementStillDedupesAgainstAnotherSavedEntry() {
        let model = makeModel()
        let taken = addressResult(id: "taken")
        model.setPlace(taken, role: .home)
        let original = SavedDestinationDraft(
            target: .destination(existing: nil),
            result: addressResult(id: "a"),
            label: "Chez Léa",
            systemImage: "heart.fill"
        )

        let draft = SavedDestinationEditing.draft(
            for: taken,
            context: .replacement(original),
            in: model
        )

        XCTAssertEqual(draft.role, .home)
    }

    @MainActor
    func testSavingADestinationDraftAddsItToTheAccount() {
        let model = makeModel()
        let draft = SavedDestinationEditing.draft(
            for: addressResult(id: "a"),
            context: .destination,
            in: model
        )

        SavedDestinationEditing.save(
            draft,
            label: "Salle de sport",
            systemImage: "dumbbell.fill",
            in: model
        )

        XCTAssertEqual(model.destinations.count, 1)
        XCTAssertEqual(model.destinations.first?.label, "Salle de sport")
        XCTAssertEqual(model.destinations.first?.systemImage, "dumbbell.fill")
    }

    @MainActor
    func testSavingAPlaceDraftPinsIt() {
        let model = makeModel()
        let draft = SavedDestinationEditing.draft(
            for: addressResult(id: "a"),
            context: .place(.home),
            in: model
        )

        SavedDestinationEditing.save(
            draft,
            label: "Maison",
            systemImage: "house.fill",
            in: model
        )

        XCTAssertNotNil(model.place(for: .home))
        // A pinned role never leaks into the free-form list.
        XCTAssertTrue(model.destinations.isEmpty)
    }

    @MainActor
    func testDeleteActionIsAbsentOnANewDraftAndPresentOnAnExistingOne() throws {
        let model = makeModel()
        let result = addressResult(id: "a")

        let newDraft = SavedDestinationEditing.draft(
            for: result,
            context: .place(.home),
            in: model
        )
        XCTAssertNil(SavedDestinationEditing.deleteAction(for: newDraft, in: model))

        model.setPlace(result, role: .home)
        let existingDraft = SavedDestinationEditing.draft(
            for: result,
            context: .place(.home),
            in: model
        )
        let delete = try XCTUnwrap(
            SavedDestinationEditing.deleteAction(for: existingDraft, in: model)
        )
        delete()

        XCTAssertNil(model.place(for: .home))
    }

    @MainActor
    func testDeletingADestinationRemovesItFromTheAccount() throws {
        let model = makeModel()
        model.saveDestination(
            addressResult(id: "a"),
            label: "Salle de sport",
            systemImage: "dumbbell.fill"
        )
        let destination = try XCTUnwrap(model.destinations.first)
        let draft = SavedDestinationEditing.draft(editing: destination)

        let delete = try XCTUnwrap(SavedDestinationEditing.deleteAction(for: draft, in: model))
        delete()

        XCTAssertTrue(model.destinations.isEmpty)
    }

    // MARK: - Helpers

    @MainActor
    private func makeModel() -> AccountModel {
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        model.activateAnonymous()
        return model
    }

    private func addressResult(id: String) -> SearchResult {
        .address(AddressSearchResult(
            id: id,
            name: "Adresse \(id)",
            context: "Paris",
            coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35),
            distanceMeters: nil
        ))
    }
}
