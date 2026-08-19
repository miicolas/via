import XCTest
@testable import Via

final class LineSchemaLayoutTests: XCTestCase {
    private func stop(_ id: String, interchange: Bool = false) -> LineSchemaStop {
        LineSchemaStop(id: id, name: id, isInterchange: interchange)
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

    private func trunk(_ stops: [LineSchemaStop]) -> LineSchemaSection {
        LineSchemaSection(role: .trunk, label: nil, origins: ["O"], termini: ["T"], stops: stops)
    }

    // MARK: - Collapse rules

    func testHealthyDirectionFoldsEverythingButEndpointsAndInterchanges() {
        let rows = LineSchemaLayout.rows(
            for: direction([
                trunk([stop("a"), stop("b"), stop("c", interchange: true), stop("d"), stop("e"), stop("f")])
            ]),
            disruptions: [],
            expandedRunIDs: []
        )

        guard case .stop(let first) = rows.first else { return XCTFail("expected a stop row") }
        XCTAssertEqual(first.stop.id, "a")
        XCTAssertTrue(first.isSectionEnd)
        XCTAssertEqual(
            rows.map(\.id),
            ["a", "run-direction-0-b-b", "c", "run-direction-0-d-e", "f"]
        )
        guard case .collapsedRun(let run) = rows[3] else { return XCTFail("expected a folded run") }
        XCTAssertEqual(run.hiddenCount, 2)
    }

    func testExpandedRunShowsItsStops() {
        let rows = LineSchemaLayout.rows(
            for: direction([trunk([stop("a"), stop("b"), stop("c"), stop("d")])]),
            disruptions: [],
            expandedRunIDs: ["run-direction-0-b-c"]
        )

        XCTAssertEqual(rows.map(\.id), ["a", "b", "c", "d"])
    }

    func testDisruptedStopsSurfaceWithOneHealthyNeighbour() {
        let rows = LineSchemaLayout.rows(
            for: direction([
                trunk([stop("a"), stop("b"), stop("c"), stop("d"), stop("e"), stop("f"), stop("g")])
            ]),
            disruptions: [disruption(.suspended, from: "c", to: "d")],
            expandedRunIDs: []
        )

        // b and e are the healthy context stops around the c–d cut.
        XCTAssertEqual(rows.map(\.id), ["a", "b", "c", "d", "e", "run-direction-0-f-f", "g"])
        guard case .stop(let cut) = rows[2] else { return XCTFail("expected a stop row") }
        XCTAssertEqual(cut.condition, .suspended)
        XCTAssertEqual(cut.railBelow, .cut(.suspended))
        // The healthy context stop keeps its healthy rails: the cut starts at c.
        guard case .stop(let context) = rows[1] else { return XCTFail("expected a stop row") }
        XCTAssertNil(context.condition)
        XCTAssertEqual(context.railBelow, .line)
        XCTAssertEqual(context.railAbove, .line)
    }

    func testUpcomingDisruptionsLeaveTheSchemaUntouched() {
        let rows = LineSchemaLayout.rows(
            for: direction([trunk([stop("a"), stop("b"), stop("c"), stop("d")])]),
            disruptions: [disruption(.suspended, from: "b", to: "c", active: false)],
            expandedRunIDs: []
        )

        XCTAssertEqual(rows.map(\.id), ["a", "run-direction-0-b-c", "d"])
    }

    // MARK: - Severity

    func testOverlappingCutsKeepTheWorstSeverity() {
        let rows = LineSchemaLayout.rows(
            for: direction([trunk([stop("a"), stop("b"), stop("c"), stop("d")])]),
            disruptions: [
                disruption(.attention, from: "a", to: "d"),
                disruption(.suspended, from: "b", to: "c"),
            ],
            expandedRunIDs: []
        )

        let conditions = rows.compactMap { row -> LineCondition? in
            guard case .stop(let stopRow) = row else { return nil }
            return stopRow.condition
        }
        XCTAssertEqual(conditions, [.attention, .suspended, .suspended, .attention])
        guard case .stop(let second) = rows[1] else { return XCTFail("expected a stop row") }
        XCTAssertEqual(second.railBelow, .cut(.suspended))
        XCTAssertEqual(second.railAbove, .cut(.attention))
    }

    // MARK: - Cross-section projection

    /// Trunk → shared sub-trunk → leaf branch: the sections carrying the cut's
    /// trains are marked, the parallel branch between them in render order is not.
    func testCutSpanningSectionsFollowsThePathAndSparesParallelBranches() {
        let sections = [
            LineSchemaSection(
                role: .trunk,
                label: nil,
                origins: ["O"],
                termini: ["cergy", "poissy", "stg"],
                stops: [stop("chatelet"), stop("nanterre")]
            ),
            LineSchemaSection(
                role: .branch,
                label: "Branche Saint-Germain",
                origins: ["O"],
                termini: ["stg"],
                stops: [stop("vesinet"), stop("stg")]
            ),
            LineSchemaSection(
                role: .branch,
                label: "Branches Cergy / Poissy",
                origins: ["O"],
                termini: ["cergy", "poissy"],
                stops: [stop("sartrouville"), stop("maisons")]
            ),
            LineSchemaSection(
                role: .branch,
                label: "Branche Cergy",
                origins: ["O"],
                termini: ["cergy"],
                stops: [stop("conflans"), stop("cergy")]
            ),
        ]
        let rows = LineSchemaLayout.rows(
            for: direction(sections),
            disruptions: [disruption(.disrupted, from: "nanterre", to: "cergy")],
            expandedRunIDs: []
        )

        let affected = rows.compactMap { row -> String? in
            guard case .stop(let stopRow) = row, stopRow.condition != nil else { return nil }
            return stopRow.stop.id
        }
        XCTAssertEqual(
            affected,
            ["nanterre", "sartrouville", "maisons", "conflans", "cergy"]
        )
    }

    func testCutBetweenParallelBranchesIsIgnored() {
        let sections = [
            LineSchemaSection(
                role: .branch,
                label: "Branche Cergy",
                origins: ["O"],
                termini: ["cergy"],
                stops: [stop("conflans"), stop("cergy")]
            ),
            LineSchemaSection(
                role: .branch,
                label: "Branche Poissy",
                origins: ["O"],
                termini: ["poissy"],
                stops: [stop("acheres"), stop("poissy")]
            ),
        ]
        let rows = LineSchemaLayout.rows(
            for: direction(sections),
            disruptions: [disruption(.suspended, from: "cergy", to: "poissy")],
            expandedRunIDs: []
        )

        XCTAssertFalse(rows.contains { row in
            guard case .stop(let stopRow) = row else { return false }
            return stopRow.condition != nil
        })
    }

    func testBranchSectionsGetTheirHeader() {
        let rows = LineSchemaLayout.rows(
            for: direction([
                trunk([stop("a"), stop("b")]),
                LineSchemaSection(
                    role: .branch,
                    label: "Branche Cergy",
                    origins: ["O"],
                    termini: ["cergy"],
                    stops: [stop("conflans"), stop("cergy")]
                ),
            ]),
            disruptions: [],
            expandedRunIDs: []
        )

        XCTAssertEqual(
            rows.map(\.id),
            ["a", "b", "header-direction-0-1", "conflans", "cergy"]
        )
        guard case .sectionHeader(_, let title) = rows[2] else {
            return XCTFail("expected a section header")
        }
        XCTAssertEqual(title, "Branche Cergy")
    }
}
