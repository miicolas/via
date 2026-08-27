import XCTest
@testable import Via

final class LinePlanTests: XCTestCase {
    private func stop(_ id: String) -> LineSchemaStop {
        LineSchemaStop(id: id, name: id)
    }

    private func trunk(
        _ stops: [String],
        origins: [String] = ["O"],
        termini: [String] = ["T"]
    ) -> LineSchemaSection {
        LineSchemaSection(
            role: .trunk,
            label: nil,
            origins: origins,
            termini: termini,
            stops: stops.map { stop($0) }
        )
    }

    private func branch(
        _ stops: [String],
        origins: [String],
        termini: [String]
    ) -> LineSchemaSection {
        LineSchemaSection(
            role: .branch,
            label: nil,
            origins: origins,
            termini: termini,
            stops: stops.map { stop($0) }
        )
    }

    private func direction(_ sections: [LineSchemaSection]) -> LineDirection {
        LineDirection(id: "direction-0", directionId: 0, label: "Terminus", sections: sections)
    }

    private func disruption(
        _ condition: LineCondition,
        from: String,
        to: String,
        active: Bool = true
    ) -> LineDisruption {
        LineDisruption(
            id: "d-\(condition)-\(from)-\(to)",
            condition: condition,
            isActive: active,
            cause: nil,
            title: nil,
            message: nil,
            periods: [],
            impactedSections: [
                LineImpactedSection(fromStopID: from, fromName: from, toStopID: to, toName: to)
            ],
            updatedAt: nil
        )
    }

    /// The RER-A shape: three branches feeding the trunk, two leaving it, with
    /// Cergy and Poissy sharing a stem.
    private var branched: LineDirection {
        direction([
            branch(["stg-end", "stg"], origins: ["stg"], termini: ["mlv", "boissy"]),
            branch(["cergy-end", "cergy"], origins: ["cergy"], termini: ["mlv", "boissy"]),
            branch(["poissy-end", "poissy"], origins: ["poissy"], termini: ["mlv", "boissy"]),
            branch(["sartrouville"], origins: ["cergy", "poissy"], termini: ["mlv", "boissy"]),
            trunk(
                ["nanterre", "defense", "chatelet", "vincennes"],
                origins: ["stg", "cergy", "poissy"],
                termini: ["mlv", "boissy"]
            ),
            branch(["fontenay", "mlv"], origins: ["stg", "cergy", "poissy"], termini: ["mlv"]),
            branch(["joinville", "boissy"], origins: ["stg", "cergy", "poissy"], termini: ["boissy"]),
        ])
    }

    // MARK: - Strips

    func testASingleTrunkIsOneOpenStrip() {
        let strips = LinePlan.strips(
            for: direction([trunk(["a", "b", "c"])]),
            disruptions: []
        )

        XCTAssertEqual(strips.count, 1)
        XCTAssertEqual(strips[0].role, .trunk)
        XCTAssertEqual(strips[0].stops.map(\.stop.id), ["a", "b", "c"])
        XCTAssertEqual(strips[0].stops.map(\.isEnd), [true, false, true])
    }

    func testEachBranchIsOneCompleteStripNamedByItsFarEnd() {
        let strips = LinePlan.strips(for: branched, disruptions: [])

        XCTAssertEqual(strips.map(\.role), [
            .branch(name: "stg-end"),
            .branch(name: "cergy-end"),
            .branch(name: "poissy-end"),
            .trunk,
            .branch(name: "mlv"),
            .branch(name: "boissy"),
        ])
        // The shared stem rides at the head of both branches that use it, the
        // way a rider reads it off the platform.
        XCTAssertEqual(strips[1].stops.map(\.stop.id), ["cergy-end", "cergy", "sartrouville"])
        XCTAssertEqual(strips[2].stops.map(\.stop.id), ["poissy-end", "poissy", "sartrouville"])
        XCTAssertEqual(strips[3].stops.map(\.stop.id), ["nanterre", "defense", "chatelet", "vincennes"])
    }

    func testTheExpandedDiagramDrawsEveryPhysicalStationOnce() {
        let strips = LinePlan.diagramStrips(for: branched, disruptions: [])
        let stationIDs = strips.flatMap { $0.stops.map(\.stop.id) }

        XCTAssertEqual(stationIDs.count, Set(stationIDs).count)
        XCTAssertEqual(stationIDs.filter { $0 == "sartrouville" }.count, 1)
        XCTAssertEqual(strips.filter { $0.role == .trunk }.count, 1)
    }

    func testAFeedWithoutATrunkHangsThePlanOffItsMostSharedSection() {
        // No section is named a trunk — a server that has not rebuilt its
        // schema yet. The stretch both services share carries the plan, even
        // though a branch is longer.
        let strips = LinePlan.strips(
            for: direction([
                branch(["a", "b", "c", "d"], origins: ["x"], termini: ["t"]),
                branch(["e", "f"], origins: ["y"], termini: ["t"]),
                branch(["g", "h"], origins: ["x", "y"], termini: ["t"]),
            ]),
            disruptions: []
        )

        XCTAssertEqual(strips.map(\.role), [.branch(name: "a"), .branch(name: "e"), .trunk])
        XCTAssertEqual(strips[2].stops.map(\.stop.id), ["g", "h"])
    }

    // MARK: - Disruptions

    func testACutInsideTheTrunkMarksItsStopsAndRails() {
        let strips = LinePlan.strips(
            for: direction([trunk(["a", "b", "c", "d"])]),
            disruptions: [disruption(.suspended, from: "b", to: "c")]
        )

        XCTAssertEqual(strips[0].stops.map(\.condition), [nil, .suspended, .suspended, nil])
        XCTAssertEqual(strips[0].stops[1].railBelow, .cut(.suspended))
        XCTAssertEqual(strips[0].stops[0].railBelow, .line)
        XCTAssertEqual(strips[0].condition, .suspended)
    }

    func testOnlyTheEdgesOfACutCarryThePictogram() {
        let strips = LinePlan.strips(
            for: direction([trunk(["a", "b", "c", "d", "e"])]),
            disruptions: [disruption(.suspended, from: "b", to: "d")]
        )

        XCTAssertEqual(strips[0].stops.map(\.isCutEdge), [false, true, false, true, false])
    }

    func testACutFromTheTrunkIntoABranchSparesTheParallelBranches() {
        let strips = LinePlan.strips(
            for: branched,
            disruptions: [disruption(.disrupted, from: "chatelet", to: "mlv")]
        )

        let affected = strips.map { strip in
            strip.stops.filter { $0.condition != nil }.map(\.stop.id)
        }
        XCTAssertEqual(affected, [
            [],                          // Saint-Germain branch: untouched
            [],                          // Cergy branch: untouched
            [],                          // Poissy branch: untouched
            ["chatelet", "vincennes"],   // trunk, from the cut to the fork
            ["fontenay", "mlv"],         // the whole branch behind it
            [],                          // the parallel Boissy branch: untouched
        ])
    }

    func testACutStraddlingTheTrunkMarksEverythingInBetween() {
        let strips = LinePlan.strips(
            for: branched,
            disruptions: [disruption(.suspended, from: "cergy", to: "mlv")]
        )

        XCTAssertEqual(strips[1].stops.filter { $0.condition != nil }.map(\.stop.id),
                       ["cergy", "sartrouville"])
        XCTAssertEqual(strips[3].stops.allSatisfy { $0.condition == .suspended }, true)
        XCTAssertEqual(strips[4].stops.allSatisfy { $0.condition == .suspended }, true)
        // Still nothing on the branches the trains never reach.
        XCTAssertNil(strips[0].condition)
        XCTAssertNil(strips[5].condition)
    }

    func testACutBetweenTwoParallelBranchesIsIgnored() {
        let strips = LinePlan.strips(
            for: branched,
            disruptions: [disruption(.suspended, from: "cergy", to: "poissy")]
        )

        XCTAssertTrue(strips.allSatisfy { $0.condition == nil })
    }

    func testUpcomingDisruptionsLeaveThePlanUntouched() {
        let strips = LinePlan.strips(
            for: direction([trunk(["a", "b", "c"])]),
            disruptions: [disruption(.suspended, from: "a", to: "c", active: false)]
        )

        XCTAssertTrue(strips.allSatisfy { $0.condition == nil })
    }

    // MARK: - Station marks

    func testAStationInsideASuspensionIsStruckThroughAndItsEdgesAreOnlyTinted() {
        let strips = LinePlan.strips(
            for: direction([trunk(["a", "b", "c", "d", "e"])]),
            disruptions: [disruption(.suspended, from: "b", to: "d")]
        )

        XCTAssertEqual(strips[0].stops.map(\.mark), [
            .open,
            .warned(.suspended),  // trains turn back here
            .closed(.suspended),  // nothing calls here
            .warned(.suspended),  // and here
            .open,
        ])
    }

    func testALesserDisruptionOnlyTintsTheStationsItTouches() {
        let strips = LinePlan.strips(
            for: direction([trunk(["a", "b", "c", "d"])]),
            disruptions: [disruption(.disrupted, from: "a", to: "d")]
        )

        XCTAssertEqual(strips[0].stops.map(\.mark), [
            .warned(.disrupted),
            .warned(.disrupted),
            .warned(.disrupted),
            .warned(.disrupted),
        ])
    }

    func testAnUndisruptedPlanMarksNothing() {
        let strips = LinePlan.strips(
            for: direction([trunk(["a", "b", "c"])]),
            disruptions: []
        )

        XCTAssertTrue(strips[0].stops.allSatisfy { $0.mark == .open })
    }

    func testTheRailStyleTravelsToTheJourneyTimelineWithTheLineColour() {
        XCTAssertEqual(
            LinePlan.RailStyle.line.timelineStyle(colorHex: "FFCE00"),
            .line(colorHex: "FFCE00")
        )
        XCTAssertEqual(LinePlan.RailStyle.none.timelineStyle(colorHex: "FFCE00"), .none)
        // A cut drops the line colour: it is the disruption that tints it.
        XCTAssertEqual(
            LinePlan.RailStyle.cut(.suspended).timelineStyle(colorHex: "FFCE00"),
            .cut(.suspended)
        )
    }

    // MARK: - Severity

    func testOverlappingCutsKeepTheWorstSeverity() {
        let strips = LinePlan.strips(
            for: direction([trunk(["a", "b", "c", "d"])]),
            disruptions: [
                disruption(.attention, from: "a", to: "d"),
                disruption(.suspended, from: "b", to: "c"),
            ]
        )

        XCTAssertEqual(
            strips[0].stops.map(\.condition),
            [.attention, .suspended, .suspended, .attention]
        )
        XCTAssertEqual(strips[0].stops[1].railBelow, .cut(.suspended))
        XCTAssertEqual(strips[0].stops[1].railAbove, .cut(.attention))
        XCTAssertEqual(strips[0].condition, .suspended)
    }
}
