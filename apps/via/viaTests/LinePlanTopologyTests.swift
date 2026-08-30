import XCTest
@testable import Via

final class LinePlanTopologyTests: XCTestCase {
    func testRERAKeepsEveryOfficialJunctionAndNeverInventsAPoissyConnection() {
        let detail = PreviewLineStatusRepository.rerADetail
        let diagram = LinePlan.completeDiagram(
            for: detail.schemaDirections,
            disruptions: []
        )
        let stopIDs = diagram.sections.flatMap(\.stops).map(\.stop.id)
        let segments = physicalSegments(in: diagram)

        XCTAssertEqual(stopIDs.count, 46)
        XCTAssertEqual(Set(stopIDs).count, 46)
        XCTAssertTrue(segments.contains(segment("IDFM:71651", "IDFM:71630")))
        XCTAssertTrue(segments.contains(segment("IDFM:71651", "IDFM:71718")))
        XCTAssertTrue(segments.contains(segment("IDFM:70945", "IDFM:64741")))
        XCTAssertTrue(segments.contains(segment("IDFM:70945", "IDFM:70956")))
        XCTAssertTrue(segments.contains(segment("IDFM:65048", "IDFM:73604")))
        XCTAssertTrue(segments.contains(segment("IDFM:65048", "IDFM:65190")))
        XCTAssertFalse(segments.contains(segment("IDFM:64883", "IDFM:73604")))
    }

    func testRERABranchesNameTheirActualJunctions() throws {
        let detail = PreviewLineStatusRepository.rerADetail
        let diagram = LinePlan.completeDiagram(
            for: detail.schemaDirections,
            disruptions: []
        )

        XCTAssertEqual(try junction(for: "IDFM:66834", in: diagram), "Maisons-Laffitte")
        XCTAssertEqual(try junction(for: "IDFM:64883", in: diagram), "Maisons-Laffitte")
        XCTAssertEqual(try junction(for: "IDFM:64589", in: diagram), "Nanterre - Préfecture")
        XCTAssertEqual(try junction(for: "IDFM:72881", in: diagram), "Vincennes")
        XCTAssertEqual(try junction(for: "IDFM:68385", in: diagram), "Vincennes")
    }

    private func physicalSegments(in diagram: LinePlan.Diagram) -> Set<String> {
        let internalSegments = diagram.sections.flatMap { section in
            zip(section.stops, section.stops.dropFirst()).map {
                segment($0.0.stop.id, $0.1.stop.id)
            }
        }
        let junctionSegments = diagram.edges.map {
            segment($0.fromStopID, $0.toStopID)
        }
        return Set(internalSegments + junctionSegments)
    }

    private func junction(
        for terminalID: String,
        in diagram: LinePlan.Diagram
    ) throws -> String? {
        let section = try XCTUnwrap(
            diagram.sections.first { section in
                section.stops.contains { $0.stop.id == terminalID }
            }
        )
        guard case .branch(_, let junction) = section.role else {
            XCTFail("Le terminus \(terminalID) n’est pas présenté comme une branche.")
            return nil
        }
        return junction
    }

    private func segment(_ first: String, _ second: String) -> String {
        first < second ? "\(first)|\(second)" : "\(second)|\(first)"
    }
}
