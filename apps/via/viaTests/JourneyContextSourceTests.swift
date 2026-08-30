import XCTest
@testable import Via

@MainActor
final class JourneyContextSourceTests: XCTestCase {
    func testPlannedDraftOnlyCountsForItsOwnSheet() async {
        let fixture = makeFixture()
        let journey = JourneyResult.mapPreview.journeys[0]
            .identified(as: JourneyID(rawValue: "planned-journey"))
        await fixture.plannedJourneyDraftModel.plan(
            journey: journey,
            destination: destination,
            source: .realtime,
            planningPolicy: JourneyPlanningPolicy()
        )

        let presented = fixture.source.current(
            for: .sheet(.plannedJourney(journey.id))
        )
        XCTAssertEqual(presented?.journey.id, journey.id)
        XCTAssertEqual(presented?.destination, destination)

        // Off its sheet, the draft never leaks onto the map.
        XCTAssertNil(fixture.source.current(for: .hidden))
        XCTAssertNil(fixture.source.current(for: .search))
    }

    func testSheetResolutionOffersProvidersOnlyWhenPresenting() async {
        let fixture = makeFixture()
        let journey = JourneyResult.mapPreview.journeys[0]
            .identified(as: JourneyID(rawValue: "planned-journey"))
        await fixture.plannedJourneyDraftModel.plan(
            journey: journey,
            destination: destination,
            source: .realtime,
            planningPolicy: JourneyPlanningPolicy()
        )

        XCTAssertEqual(
            fixture.source.context(for: journey.id, isPlanned: true, isScheduled: false)?
                .journey.id,
            journey.id
        )
        XCTAssertNil(
            fixture.source.context(for: journey.id, isPlanned: false, isScheduled: false)
        )
    }

    // MARK: - Fixtures

    private let destination = JourneyDestination.address(
        id: "destination",
        name: "La Défense",
        context: nil,
        coordinate: GeoCoordinate(latitude: 48.8918, longitude: 2.2380)
    )

    private struct Fixture {
        let source: JourneyContextSource
        let plannedJourneyDraftModel: PlannedJourneyDraftModel
    }

    private func makeFixture() -> Fixture {
        let locationModel = LocationModel(
            adapter: InMemoryLocationAdapter(
                coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470)
            )
        )
        let accountModel = AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        let plannedJourneyDraftModel = PlannedJourneyDraftModel()
        let source = JourneyContextSource(
            searchViewModel: SearchViewModel(
                repository: InMemorySearchRepository.preview,
                journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
                locationModel: locationModel,
                account: accountModel
            ),
            plannedJourneyDraftModel: plannedJourneyDraftModel,
            journeyNotificationCoordinator: .preview,
            activeJourneyModel: ActiveJourneyModel(
                locationModel: locationModel,
                journeyRepository: InMemoryJourneyRepository(result: .mapPreview)
            )
        )
        return Fixture(source: source, plannedJourneyDraftModel: plannedJourneyDraftModel)
    }
}
