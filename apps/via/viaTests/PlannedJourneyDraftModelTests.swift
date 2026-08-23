import XCTest
@testable import Via

@MainActor
final class PlannedJourneyDraftModelTests: XCTestCase {
    func testPlannedJourneyPersistsAndRestoresItsLaunchContext() async throws {
        let suiteName = "dev.via.planned-journey-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsPlannedJourneyDraftStore(defaults: defaults)
        let plannedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let policy = JourneyPlanningPolicy(
            requiredModes: [.metro],
            excludedModes: [.bus],
            requiresAccessibleStations: true
        )
        let first = PlannedJourneyDraftModel(store: store, now: { plannedAt })

        let didPlan = await first.plan(
            journey: journey,
            destination: destination,
            source: .realtime,
            planningPolicy: policy
        )

        XCTAssertTrue(didPlan)
        let restored = PlannedJourneyDraftModel(store: store)
        await restored.restore()
        XCTAssertEqual(restored.draft?.journey, journey)
        XCTAssertEqual(restored.draft?.destination, destination)
        XCTAssertEqual(restored.draft?.source, .realtime)
        XCTAssertEqual(restored.draft?.planningPolicy, policy)
        XCTAssertEqual(restored.draft?.plannedAt, plannedAt)
    }

    func testPlanningAnotherJourneyReplacesThePreviousDraft() async {
        let store = InMemoryPlannedJourneyDraftStore()
        let model = PlannedJourneyDraftModel(store: store)
        let alternate = JourneyResult.mapPreview.journeys[1]

        await model.plan(
            journey: journey,
            destination: destination,
            source: .realtime,
            planningPolicy: JourneyPlanningPolicy()
        )
        await model.plan(
            journey: alternate,
            destination: alternateDestination,
            source: .theoretical,
            planningPolicy: JourneyPlanningPolicy()
        )

        XCTAssertEqual(model.draft?.journey.id, alternate.id)
        XCTAssertEqual(model.draft?.destination, alternateDestination)
    }

    func testOnlyTheDraftThatStartedIsConsumed() async {
        let store = InMemoryPlannedJourneyDraftStore()
        let model = PlannedJourneyDraftModel(store: store)
        await model.plan(
            journey: journey,
            destination: destination,
            source: .realtime,
            planningPolicy: JourneyPlanningPolicy()
        )
        let planned = model.draft!
        let differentDraft = PlannedJourneyDraft(
            journey: JourneyResult.mapPreview.journeys[1],
            destination: alternateDestination,
            source: .theoretical,
            planningPolicy: JourneyPlanningPolicy(),
            plannedAt: .distantFuture
        )

        await model.consume(differentDraft)
        XCTAssertEqual(model.draft?.journey.id, journey.id)

        await model.consume(planned)
        XCTAssertNil(model.draft)

        let restored = PlannedJourneyDraftModel(store: store)
        await restored.restore()
        XCTAssertNil(restored.draft)
    }

    func testLaunchingTheDraftStartsGuidanceThenConsumesThePersistedDraft() async {
        let store = InMemoryPlannedJourneyDraftStore()
        let model = PlannedJourneyDraftModel(store: store)
        let location = LocationModel(
            adapter: InMemoryLocationAdapter(
                coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
            )
        )
        let active = ActiveJourneyModel(
            locationModel: location,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview)
        )
        await model.plan(
            journey: journey,
            destination: destination,
            source: .realtime,
            planningPolicy: JourneyPlanningPolicy()
        )

        let didLaunch = await model.launch(
            using: active,
            allowsBackgroundTracking: false
        )

        XCTAssertTrue(didLaunch)
        XCTAssertEqual(active.session?.journey.id, journey.id)
        XCTAssertNil(model.draft)
        let restored = PlannedJourneyDraftModel(store: store)
        await restored.restore()
        XCTAssertNil(restored.draft)
    }

    private var journey: Journey {
        JourneyResult.mapPreview.journeys[0]
    }

    private var destination: JourneyDestination {
        .address(
            id: "planned:destination",
            name: "La Défense",
            context: "Puteaux",
            coordinate: GeoCoordinate(latitude: 48.8918, longitude: 2.2380)
        )
    }

    private var alternateDestination: JourneyDestination {
        .station(
            id: StationID(rawValue: "planned:station"),
            name: "Nation",
            coordinate: GeoCoordinate(latitude: 48.8484, longitude: 2.3958)
        )
    }
}
