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

    func testProductionShapedRERAKeepsThePlatformMapBranchOrder() {
        let diagram = LinePlan.completeDiagram(
            for: productionShapedRERADirections(),
            disruptions: []
        )
        let stopIDs = diagram.sections.flatMap(\.stops).map(\.stop.id)
        let segments = physicalSegments(in: diagram)

        XCTAssertEqual(stopIDs.count, 46)
        XCTAssertEqual(Set(stopIDs).count, 46)
        XCTAssertFalse(segments.contains(segment("IDFM:71718", "IDFM:65190")))
        XCTAssertFalse(segments.contains(segment("IDFM:64883", "IDFM:73604")))
        XCTAssertFalse(segments.contains(segment("IDFM:66834", "IDFM:72881")))
        XCTAssertFalse(segments.contains(segment("IDFM:65048", "IDFM:70956")))
        XCTAssertFalse(segments.contains(segment("IDFM:72881", "IDFM:71718")))
        XCTAssertEqual(
            diagram.sections.map(sectionName),
            [
                "Tronc commun",
                "Boissy-Saint-Léger",
                "Marne-la-Vallée - Chessy",
                "Cergy le Haut",
                "Poissy",
                "Saint-Germain-en-Laye",
            ]
        )
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

    private func sectionName(_ section: LinePlan.Diagram.Section) -> String {
        switch section.role {
        case .main:
            "Tronc commun"
        case .branch(let name, _):
            name
        case .loop(let from, let to):
            "Boucle \(from) – \(to)"
        }
    }

    /// Same physical RER A graph as the preview fixture, partitioned exactly
    /// like the production importer: service groups can put an eastern arm
    /// before western arms even though they are not adjacent on the platform
    /// map. The display order must not inherit that incidental row order.
    private func productionShapedRERADirections() -> [LineDirection] {
        let sourceDirections = PreviewLineStatusRepository.rerADetail.schemaDirections
        let stopsByID = sourceDirections
            .flatMap(\.sections)
            .flatMap(\.stops)
            .reduce(into: [String: LineSchemaStop]()) { result, stop in
                result[stop.id] = result[stop.id] ?? stop
            }

        func stops(_ ids: [String]) -> [LineSchemaStop] {
            ids.compactMap { stopsByID[$0] }
        }

        func section(
            _ role: LineSchemaSection.Role,
            _ label: String?,
            origins: [String],
            termini: [String],
            stops ids: [String]
        ) -> LineSchemaSection {
            LineSchemaSection(
                role: role,
                label: label,
                origins: origins,
                termini: termini,
                stops: stops(ids)
            )
        }

        let boissy = [
            "IDFM:72881", "IDFM:72929", "IDFM:72998", "IDFM:73042",
            "IDFM:70359", "IDFM:70393", "IDFM:70640", "IDFM:71590", "IDFM:71630",
        ]
        let marne = [
            "IDFM:68385", "IDFM:68266", "IDFM:68105", "IDFM:68129",
            "IDFM:68123", "IDFM:68153", "IDFM:73163", "IDFM:412697",
            "IDFM:73166", "IDFM:73190", "IDFM:71718",
        ]
        let paris = [
            "IDFM:71651", "IDFM:71673", "IDFM:73626", "IDFM:474151",
            "IDFM:478926", "IDFM:71347", "IDFM:71517", "IDFM:70945",
        ]
        let stem = ["IDFM:64741", "IDFM:64918", "IDFM:65048"]
        let cergy = [
            "IDFM:73604", "IDFM:73605", "IDFM:66436",
            "IDFM:66696", "IDFM:66858", "IDFM:66834",
        ]
        let poissy = ["IDFM:65190", "IDFM:64883"]
        let saintGermain = [
            "IDFM:70956", "IDFM:70940", "IDFM:70902", "IDFM:64483",
            "IDFM:64514", "IDFM:64582", "IDFM:64589",
        ]
        let east = ["IDFM:72881", "IDFM:68385"]
        let west = ["IDFM:64589", "IDFM:66834", "IDFM:64883"]

        return [
            LineDirection(
                id: "production-direction-0",
                directionId: 0,
                label: "Saint-Germain-en-Laye / Cergy le Haut / Poissy",
                sections: [
                    section(.branch, "Branche Saint-Germain-en-Laye", origins: ["IDFM:64589"], termini: west, stops: marne),
                    section(.branch, "Branche Poissy", origins: ["IDFM:72881"], termini: ["IDFM:64883"], stops: poissy),
                    section(.branch, "Branche Cergy le Haut", origins: ["IDFM:72881"], termini: ["IDFM:66834"], stops: cergy),
                    section(.trunk, nil, origins: ["IDFM:72881", "IDFM:64589"], termini: west, stops: boissy + paris),
                    section(.branch, "Branches Cergy le Haut / Poissy", origins: ["IDFM:72881"], termini: ["IDFM:66834", "IDFM:64883"], stops: stem),
                    section(.branch, "Branche Saint-Germain-en-Laye", origins: ["IDFM:72881", "IDFM:64589"], termini: ["IDFM:64589"], stops: saintGermain),
                ]
            ),
            LineDirection(
                id: "production-direction-1",
                directionId: 1,
                label: "Boissy-Saint-Léger / Marne-la-Vallée - Chessy",
                sections: [
                    section(.branch, "Branche Cergy le Haut", origins: ["IDFM:66834"], termini: east, stops: cergy.reversed()),
                    section(.branch, "Branche Poissy", origins: ["IDFM:64883"], termini: east, stops: poissy.reversed()),
                    section(.trunk, nil, origins: ["IDFM:66834", "IDFM:64883"], termini: east, stops: (paris + stem).reversed()),
                    section(.branch, "Branche Boissy-Saint-Léger", origins: ["IDFM:66834", "IDFM:64883"], termini: ["IDFM:72881"], stops: boissy.reversed()),
                    section(.branch, "Branche Marne-la-Vallée - Chessy", origins: ["IDFM:66834", "IDFM:64883"], termini: ["IDFM:68385"], stops: marne.reversed()),
                ]
            ),
        ]
    }

    private func segment(_ first: String, _ second: String) -> String {
        first < second ? "\(first)|\(second)" : "\(second)|\(first)"
    }
}
