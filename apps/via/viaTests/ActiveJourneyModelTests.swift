import XCTest
@testable import Via

@MainActor
final class ActiveJourneyModelTests: XCTestCase {
    func testActivationPersistsAndRestoresTheSelectedJourney() async throws {
        let journey = JourneyResult.mapPreview.journeys[0]
        let store = InMemoryActiveJourneyStore()
        let location = LocationModel(adapter: InMemoryLocationAdapter())
        let now = journey.departureAt.addingTimeInterval(-5 * 60)
        let first = makeModel(location: location, store: store, now: now)

        await first.activate(
            journey: journey,
            destination: destination,
            source: .realtime,
            requestBackgroundAuthorization: true
        )

        XCTAssertEqual(first.session?.journey.id, journey.id)
        XCTAssertTrue(location.backgroundAuthorizationGranted)

        let restored = makeModel(location: location, store: store, now: now)
        await restored.restore()

        XCTAssertEqual(restored.session?.journey, journey)
        XCTAssertEqual(restored.session?.destination, destination)
        XCTAssertEqual(restored.phase, .scheduled(5 * 60))
    }

    func testManualProgressControlsRemainInsideJourneyBounds() async {
        let journey = JourneyResult.mapPreview.journeys[0]
        let now = journey.departureAt
        let model = makeModel(now: now)
        await model.activate(
            journey: journey,
            destination: destination,
            source: .realtime,
            requestBackgroundAuthorization: false
        )

        await model.moveToPreviousSection()
        XCTAssertEqual(model.session?.currentSectionIndex, 0)

        for _ in journey.sections.indices {
            await model.moveToNextSection()
        }
        XCTAssertEqual(model.session?.currentSectionIndex, journey.sections.count - 1)
    }

    func testManualFinishPublishesArrivalAndClearsPersistedSession() async throws {
        let journey = JourneyResult.mapPreview.journeys[0]
        let store = InMemoryActiveJourneyStore()
        let model = makeModel(store: store, now: journey.arrivalAt)
        await model.activate(
            journey: journey,
            destination: destination,
            source: .realtime,
            requestBackgroundAuthorization: false
        )

        await model.finishJourney()

        XCTAssertNil(model.session)
        XCTAssertEqual(model.arrival?.destinationName, destination.name)
        let persisted = await store.load()
        XCTAssertNil(persisted)
    }

    func testLocationAtDestinationAfterFinalStepCompletesJourney() async throws {
        let journey = JourneyResult.mapPreview.journeys[0]
        let store = InMemoryActiveJourneyStore()
        let location = LocationModel(adapter: InMemoryLocationAdapter(
            authorization: .denied,
            coordinate: nil
        ))
        let model = makeModel(
            location: location,
            store: store,
            now: journey.departureAt
        )
        await model.activate(
            journey: journey,
            destination: destination,
            source: .realtime,
            requestBackgroundAuthorization: false
        )

        let finalCoordinate = try XCTUnwrap(journey.sections.last?.to.coordinate)
        await model.receive(
            LocationSample(
                coordinate: finalCoordinate,
                horizontalAccuracy: 30,
                recordedAt: journey.arrivalAt
            ),
            at: journey.arrivalAt
        )

        XCTAssertNil(model.session)
        XCTAssertEqual(model.arrival?.destinationName, destination.name)
        let persisted = await store.load()
        XCTAssertNil(persisted)
    }

    func testFastestAlternativeIsProposedAndAcceptedWithoutSilentReplacement() async {
        let result = JourneyResult.mapPreview
        let current = result.journeys[0]
        let model = makeModel(
            repository: InMemoryJourneyRepository(result: result),
            now: current.departureAt
        )
        await model.activate(
            journey: current,
            destination: destination,
            source: .realtime,
            requestBackgroundAuthorization: false
        )

        model.checkForAlternative()
        await waitUntil { model.alternative != nil }

        let proposed = model.alternative?.journey
        XCTAssertEqual(model.session?.journey.id, current.id)
        XCTAssertEqual(
            proposed?.arrivalAt,
            result.journeys.dropFirst().map(\.arrivalAt).min()
        )

        await model.acceptBestAlternative()

        XCTAssertEqual(model.session?.journey.id, proposed?.id)
        XCTAssertNil(model.alternative)
    }

    private var destination: JourneyDestination {
        .address(
            id: "test:destination",
            name: "La Défense",
            context: "Puteaux",
            coordinate: GeoCoordinate(latitude: 48.8918, longitude: 2.2380)
        )
    }

    private func makeModel(
        location: LocationModel = LocationModel(adapter: InMemoryLocationAdapter()),
        repository: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
        store: any ActiveJourneyStore = InMemoryActiveJourneyStore(),
        now: Date
    ) -> ActiveJourneyModel {
        ActiveJourneyModel(
            locationModel: location,
            journeyRepository: repository,
            store: store,
            activityManager: NoOpJourneyActivityManager(),
            now: { now }
        )
    }

    private func waitUntil(
        _ predicate: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<200 {
            if predicate() { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for active journey state", file: file, line: line)
    }
}
