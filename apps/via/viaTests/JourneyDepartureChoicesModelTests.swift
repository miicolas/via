@testable import Via
import XCTest

@MainActor
final class JourneyDepartureChoicesModelTests: XCTestCase {
    func testSelectionAppliesCompleteRevisionOnlyAfterSuccess() async {
        let current = JourneyResult.mapPreview.journeys[0]
        let revised = revisedJourney(current, minutes: 5)
        let snapshot = makeSnapshot(journey: revised, choiceID: "revised")
        let model = JourneyDepartureChoicesModel(
            repository: InMemoryJourneyDepartureChoicesRepository(snapshot: snapshot)
        )
        var applied: Journey?

        await model.select(
            nextChoice,
            in: sectionID(in: current),
            journey: current,
            destination: destination,
            policy: JourneyPlanningPolicy(),
            apply: { applied = $0 }
        )

        XCTAssertEqual(applied, revised)
        XCTAssertEqual(model.groupsBySectionID.values.first?.choices.first?.id, "revised")
        XCTAssertNil(model.selectingSectionID)
    }

    func testSelectionFailureKeepsTheLastSnapshotAndJourneyUntouched() async {
        let current = JourneyResult.mapPreview.journeys[0]
        let previous = makeSnapshot(journey: current, choiceID: "previous")
        let repository = InMemoryJourneyDepartureChoicesRepository { request in
            if request.selection == nil { return previous }
            throw ViaError.unavailable
        }
        let model = JourneyDepartureChoicesModel(repository: repository)
        await model.refresh(
            journey: current,
            destination: destination,
            policy: JourneyPlanningPolicy(),
            apply: { _ in }
        )
        var applied = false

        await model.select(
            nextChoice,
            in: sectionID(in: current),
            journey: current,
            destination: destination,
            policy: JourneyPlanningPolicy(),
            apply: { _ in applied = true }
        )

        XCTAssertFalse(applied)
        XCTAssertEqual(model.groupsBySectionID.values.first?.choices.first?.id, "previous")
        XCTAssertNotNil(model.errorMessage(for: sectionID(in: current)))
    }

    func testOlderRefreshResponseCannotOverwriteTheNewestSnapshot() async {
        let current = JourneyResult.mapPreview.journeys[0]
        let gate = DepartureChoicesGate()
        let model = JourneyDepartureChoicesModel(
            repository: InMemoryJourneyDepartureChoicesRepository { _ in try await gate.resolve() }
        )

        let older = Task {
            await model.refresh(
                journey: current,
                destination: destination,
                policy: JourneyPlanningPolicy(),
                apply: { _ in }
            )
        }
        await waitUntil { await gate.count == 1 }
        let newer = Task {
            await model.refresh(
                journey: current,
                destination: destination,
                policy: JourneyPlanningPolicy(),
                apply: { _ in }
            )
        }
        await waitUntil { await gate.count == 2 }

        await gate.resume(index: 1, with: makeSnapshot(journey: current, choiceID: "newest"))
        await newer.value
        await gate.resume(index: 0, with: makeSnapshot(journey: current, choiceID: "stale"))
        await older.value

        XCTAssertEqual(model.groupsBySectionID.values.first?.choices.first?.id, "newest")
    }

    private var destination: JourneyDestination {
        .station(
            id: StationID(rawValue: "destination"),
            name: "Destination",
            coordinate: GeoCoordinate(latitude: 48.86, longitude: 2.36)
        )
    }

    private var nextChoice: JourneyDepartureChoice {
        JourneyDepartureChoice(
            id: "next",
            scheduledAt: .now.addingTimeInterval(300),
            expectedAt: nil,
            status: .scheduled,
            isSelected: false
        )
    }

    private func sectionID(in journey: Journey) -> String {
        journey.sections.first(where: { $0.kind == .transit })?.id ?? "transit"
    }

    private func makeSnapshot(journey: Journey, choiceID: String) -> JourneyDepartureChoicesSnapshot {
        JourneyDepartureChoicesSnapshot(
            journey: journey,
            generatedAt: .now,
            groups: [
                JourneyDepartureChoiceGroup(
                    sectionID: sectionID(in: journey),
                    availability: .available,
                    source: .realtime,
                    fetchedAt: .now,
                    choices: [
                        JourneyDepartureChoice(
                            id: choiceID,
                            scheduledAt: .now,
                            expectedAt: nil,
                            status: .onTime,
                            isSelected: true
                        ),
                    ]
                ),
            ]
        )
    }

    private func revisedJourney(_ journey: Journey, minutes: Int) -> Journey {
        Journey(
            id: journey.id,
            qualifier: journey.qualifier,
            durationSeconds: journey.durationSeconds + minutes * 60,
            walkingDurationSeconds: journey.walkingDurationSeconds,
            transferCount: journey.transferCount,
            departureAt: journey.departureAt,
            arrivalAt: journey.arrivalAt.addingTimeInterval(TimeInterval(minutes * 60)),
            status: journey.status,
            warnings: journey.warnings,
            accessibility: journey.accessibility,
            peak: journey.peak,
            sections: journey.sections
        )
    }

    private func waitUntil(_ condition: @escaping () async -> Bool) async {
        for _ in 0 ..< 100 {
            if await condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Condition did not become true")
    }
}

private actor DepartureChoicesGate {
    private var continuations: [CheckedContinuation<JourneyDepartureChoicesSnapshot, Error>?] = []

    var count: Int { continuations.count }

    func resolve() async throws -> JourneyDepartureChoicesSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resume(index: Int, with snapshot: JourneyDepartureChoicesSnapshot) {
        continuations[index]?.resume(returning: snapshot)
        continuations[index] = nil
    }
}
