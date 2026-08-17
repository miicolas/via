import XCTest
@testable import Via

final class JourneySegmentStripModelTests: XCTestCase {
    func testSectionsMapToContentSizedChips() {
        let model = JourneySegmentStripModel(journey: JourneyResult.mapPreview.journeys[0])

        XCTAssertEqual(model.items.count, 5)
        XCTAssertEqual(model.items[0].kind, .walk)
        XCTAssertEqual(model.items[0].minutesLabel, "4")
        XCTAssertEqual(
            model.items[1].kind,
            .transit(line: "A", mode: .rer, colorHex: "E3051C", textColorHex: "FFFFFF")
        )
        XCTAssertEqual(model.items[1].durationLabel, "15 min")
        XCTAssertEqual(model.items[2].kind, .transfer)
        XCTAssertEqual(model.items[2].minutesLabel, "3")
        XCTAssertEqual(model.items[3].durationLabel, "25 min")
        XCTAssertEqual(model.items[4].kind, .walk)
        XCTAssertEqual(model.items[4].minutesLabel, "5")
    }

    func testWalkingOnlyJourneyUsesOneReadableCapsule() {
        let base = JourneyResult.mapPreview.journeys[0]
        let walk = base.sections[0]
        let journey = Journey(
            id: JourneyID(rawValue: "walk-only"),
            qualifier: .walking,
            durationSeconds: 1_320,
            walkingDurationSeconds: 1_320,
            transferCount: 0,
            departureAt: base.departureAt,
            arrivalAt: base.departureAt.addingTimeInterval(1_320),
            status: .normal,
            warnings: [],
            sections: [walk]
        )

        let model = JourneySegmentStripModel(journey: journey)

        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.items[0].kind, .walkingOnly)
        XCTAssertEqual(model.items[0].durationLabel, "22 min")
    }

    func testZeroDurationWaitIsOmitted() {
        let base = JourneyResult.mapPreview.journeys[0]
        let place = base.sections[0].from
        let wait = JourneySection(
            id: "zero-wait",
            kind: .wait,
            durationSeconds: 0,
            from: place,
            to: place,
            departureAt: nil,
            arrivalAt: nil,
            geometry: [],
            route: nil,
            direction: nil,
            platform: nil,
            stops: []
        )
        let journey = replacingSections(of: base, with: [wait] + base.sections)

        let model = JourneySegmentStripModel(journey: journey)

        XCTAssertFalse(model.items.contains { $0.id == "zero-wait" })
    }

    func testWaitAndTransferProduceCompactBlocks() {
        let base = JourneyResult.mapPreview.journeys[0]
        let place = base.sections[0].from
        let wait = JourneySection(
            id: "wait",
            kind: .wait,
            durationSeconds: 120,
            from: place,
            to: place,
            departureAt: nil,
            arrivalAt: nil,
            geometry: [],
            route: nil,
            direction: nil,
            platform: nil,
            stops: []
        )
        let transfer = base.sections[2]

        let model = JourneySegmentStripModel(
            journey: replacingSections(of: base, with: [wait, transfer])
        )

        XCTAssertEqual(model.items.map(\.kind), [.wait, .transfer])
        XCTAssertEqual(model.items.map(\.minutesLabel), ["2", "3"])
    }

    func testZeroDurationTransitRemainsReadable() {
        let base = JourneyResult.mapPreview.journeys[0]
        let section = base.sections[1]
        let transit = JourneySection(
            id: "zero-transit",
            kind: .transit,
            durationSeconds: 0,
            from: section.from,
            to: section.to,
            departureAt: nil,
            arrivalAt: nil,
            geometry: section.geometry,
            route: section.route,
            direction: section.direction,
            platform: section.platform,
            stops: section.stops
        )

        let model = JourneySegmentStripModel(
            journey: replacingSections(of: base, with: [transit])
        )

        XCTAssertEqual(model.items[0].durationLabel, "< 1 min")
        XCTAssertEqual(model.items[0].minutesLabel, "1")
    }

    func testTotalDurationRoundsUpToWholeMinutes() {
        let journey = JourneyResult.mapPreview.journeys[0]

        XCTAssertEqual(journey.totalDurationMinutes, 52)
        XCTAssertEqual(journey.totalDurationLabel, "52 min")
    }

    private func replacingSections(
        of journey: Journey,
        with sections: [JourneySection]
    ) -> Journey {
        Journey(
            id: journey.id,
            qualifier: journey.qualifier,
            durationSeconds: journey.durationSeconds,
            walkingDurationSeconds: journey.walkingDurationSeconds,
            transferCount: journey.transferCount,
            departureAt: journey.departureAt,
            arrivalAt: journey.arrivalAt,
            status: journey.status,
            warnings: journey.warnings,
            sections: sections
        )
    }
}
