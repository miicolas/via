import XCTest
@testable import Via

private struct StubDetailRepository: LineStatusRepository {
    let detail: LineDetail

    func statuses() async throws -> LineStatusBoard { throw ViaError.unavailable }
    func searchLines(query: String) async throws -> LineStatusBoard { throw ViaError.unavailable }
    func detail(lineID: RouteID) async throws -> LineDetail { detail }
}

final class LineDetailViewModelTests: XCTestCase {
    @MainActor
    private func makeViewModel(detail: LineDetail) async -> LineDetailViewModel {
        let viewModel = LineDetailViewModel(
            repository: StubDetailRepository(detail: detail),
            lineID: detail.route.id
        )
        await viewModel.refresh()
        return viewModel
    }

    @MainActor
    func testTheCompletePlanKeepsTheRealRERAStemAndFiveTerminalArms() async {
        let viewModel = await makeViewModel(detail: PreviewLineStatusRepository.rerADetail)

        XCTAssertEqual(viewModel.diagram.sections.map(\.role), [
            .main,
            .branch(name: "Boissy-Saint-Léger", junction: "Vincennes"),
            .branch(name: "Marne-la-Vallée - Chessy", junction: "Vincennes"),
            .branch(name: "Cergy le Haut", junction: "Maisons-Laffitte"),
            .branch(name: "Poissy", junction: "Maisons-Laffitte"),
            .branch(name: "Saint-Germain-en-Laye", junction: "Nanterre - Préfecture"),
        ])
        XCTAssertEqual(viewModel.diagram.sections[0].stops.map(\.stop.name), [
            "Vincennes", "Nation", "Gare de Lyon", "Châtelet - Les Halles", "Auber",
            "Charles de Gaulle - Étoile", "La Défense", "Nanterre - Préfecture",
            "Houilles - Carrières-sur-Seine", "Sartrouville", "Maisons-Laffitte",
        ])
    }

    @MainActor
    func testTheCompleteRERADiagramNamesAllFiveTerminalBranches() async {
        let viewModel = await makeViewModel(detail: PreviewLineStatusRepository.rerADetail)

        let branchNames: [String] = viewModel.diagram.sections.compactMap { section in
            guard case .branch(let name, _) = section.role else { return nil }
            return name
        }

        XCTAssertEqual(Set(branchNames), [
            "Saint-Germain-en-Laye",
            "Cergy le Haut",
            "Poissy",
            "Marne-la-Vallée - Chessy",
            "Boissy-Saint-Léger",
        ])
        XCTAssertEqual(branchNames.count, 5)

        let stationIDs = viewModel.diagram.sections.flatMap { $0.stops.map(\.stop.id) }
        XCTAssertEqual(stationIDs.count, Set(stationIDs).count)
    }

    @MainActor
    func testTheRERAPreviewContainsTheCompleteOfficialStationSet() async {
        let viewModel = await makeViewModel(detail: PreviewLineStatusRepository.rerADetail)
        let stationNames = Set(
            viewModel.diagram.sections.flatMap { section in
                section.stops.map(\.stop.name)
            }
        )

        XCTAssertEqual(stationNames, [
            "Achères Grand Cormier",
            "Achères Ville",
            "Auber",
            "Boissy-Saint-Léger",
            "Bry-sur-Marne",
            "Bussy-Saint-Georges",
            "Cergy Préfecture",
            "Cergy Saint-Christophe",
            "Cergy le Haut",
            "Champigny",
            "Charles de Gaulle - Étoile",
            "Chatou - Croissy",
            "Châtelet - Les Halles",
            "Conflans Fin d'Oise",
            "Fontenay-sous-Bois",
            "Gare de Lyon",
            "Houilles - Carrières-sur-Seine",
            "Joinville-le-Pont",
            "La Défense",
            "La Varenne - Chennevières",
            "Le Parc de Saint-Maur",
            "Le Vésinet - Centre",
            "Le Vésinet - Le Pecq",
            "Lognes",
            "Maisons-Laffitte",
            "Marne-la-Vallée - Chessy",
            "Nanterre - Préfecture",
            "Nanterre - Ville",
            "Nanterre Université",
            "Nation",
            "Neuilly-Plaisance",
            "Neuville - Université",
            "Nogent-sur-Marne",
            "Noisiel",
            "Noisy - Champs",
            "Noisy-le-Grand - Mont d'Est",
            "Poissy",
            "Rueil-Malmaison",
            "Saint-Germain-en-Laye",
            "Saint-Maur - Créteil",
            "Sartrouville",
            "Sucy - Bonneuil",
            "Torcy",
            "Val d'Europe",
            "Val de Fontenay",
            "Vincennes",
        ])
    }

    func testASingleSidedForkDoesNotTurnTheOppositeTerminusIntoAThirdBranch() {
        func stops(_ names: [String]) -> [LineSchemaStop] {
            names.map { LineSchemaStop(id: $0, name: $0) }
        }

        let direction = LineDirection(
            id: "single-sided-fork",
            directionId: 0,
            label: "North",
            sections: [
                LineSchemaSection(
                    role: .branch,
                    label: "Branche A",
                    origins: ["A"],
                    termini: ["North"],
                    stops: stops(["A", "A near"])
                ),
                LineSchemaSection(
                    role: .branch,
                    label: "Branche B",
                    origins: ["B"],
                    termini: ["North"],
                    stops: stops(["B", "B near"])
                ),
                LineSchemaSection(
                    role: .trunk,
                    label: nil,
                    origins: ["A", "B"],
                    termini: ["North"],
                    stops: stops(["Junction", "Middle", "North"])
                ),
            ]
        )

        let diagram = LinePlan.completeDiagram(for: [direction], disruptions: [])
        let branchNames: [String] = diagram.sections.compactMap { section in
            guard case .branch(let name, _) = section.role else { return nil }
            return name
        }

        XCTAssertEqual(Set(branchNames), ["A", "B"])
        XCTAssertEqual(diagram.sections.first?.stops.map(\.stop.id), [
            "Junction", "Middle", "North",
        ])
    }

    @MainActor
    func testLegacyBranchesBackThePlanWhileDirectionsAreEmpty() async {
        let legacy = LineDetail(
            route: PreviewLineStatusRepository.metro1,
            branches: [
                LineBranch(
                    id: "p-m1-0",
                    directionId: 0,
                    headsign: "Château de Vincennes",
                    isCanonical: true,
                    stops: [
                        LineStop(id: "a", name: "La Défense"),
                        LineStop(id: "b", name: "Nation"),
                    ]
                )
            ],
            directions: [],
            source: .live,
            fetchedAt: nil,
            disruptions: []
        )
        let viewModel = await makeViewModel(detail: legacy)

        XCTAssertEqual(viewModel.diagram.sections.flatMap { $0.stops.map(\.stop.id) }, ["a", "b"])
    }

    @MainActor
    func testTheCompletePlanIncludesHealthyAndDisruptedBranches() async {
        let viewModel = await makeViewModel(detail: PreviewLineStatusRepository.rerADetail)

        XCTAssertTrue(viewModel.diagram.sections.contains { section in
            section.stops.allSatisfy { $0.condition == nil }
        })
        XCTAssertTrue(viewModel.diagram.sections.contains { section in
            section.stops.contains { $0.condition != nil }
        })
    }

    @MainActor
    func testTheCompletePlanIncludesTheDirectionSpecificLoopOfMetro10() async {
        let detail = LineDetail(
            route: PreviewLineStatusRepository.metro1,
            branches: [],
            directions: [
                LineDirection(
                    id: "direction-0",
                    directionId: 0,
                    label: "Terminus ouest",
                    sections: [
                        LineSchemaSection(
                            role: .trunk,
                            label: nil,
                            origins: ["east"],
                            termini: ["west"],
                            stops: [
                                LineSchemaStop(id: "javel", name: "Javel"),
                                LineSchemaStop(id: "eglise", name: "Église d'Auteuil"),
                                LineSchemaStop(id: "auteuil", name: "Michel-Ange - Auteuil"),
                                LineSchemaStop(id: "porte", name: "Porte d'Auteuil"),
                                LineSchemaStop(id: "boulogne", name: "Boulogne Jean Jaurès"),
                                LineSchemaStop(id: "pont", name: "Boulogne Pont de Saint-Cloud"),
                            ]
                        )
                    ]
                ),
                LineDirection(
                    id: "direction-1",
                    directionId: 1,
                    label: "Terminus est",
                    sections: [
                        LineSchemaSection(
                            role: .trunk,
                            label: nil,
                            origins: ["west"],
                            termini: ["east"],
                            stops: [
                                LineSchemaStop(id: "pont", name: "Boulogne Pont de Saint-Cloud"),
                                LineSchemaStop(id: "boulogne", name: "Boulogne Jean Jaurès"),
                                LineSchemaStop(id: "molitor", name: "Michel-Ange - Molitor"),
                                LineSchemaStop(id: "chardon", name: "Chardon Lagache"),
                                LineSchemaStop(id: "mirabeau", name: "Mirabeau"),
                                LineSchemaStop(id: "javel", name: "Javel"),
                            ]
                        )
                    ]
                ),
            ],
            source: .live,
            fetchedAt: nil,
            disruptions: []
        )
        let viewModel = await makeViewModel(detail: detail)

        XCTAssertEqual(
            Set(viewModel.diagram.sections.flatMap { $0.stops.map(\.stop.id) }),
            [
                "javel", "eglise", "auteuil", "porte", "boulogne", "pont",
                "molitor", "chardon", "mirabeau",
            ]
        )
        XCTAssertEqual(viewModel.diagram.sections.map { $0.stops.map(\.stop.id) }, [
            ["javel", "eglise", "auteuil", "porte", "boulogne", "pont"],
            ["mirabeau", "chardon", "molitor"],
        ])
        XCTAssertEqual(viewModel.diagram.sections.map(\.role), [
            .main,
            .loop(from: "Javel", to: "Boulogne Jean Jaurès"),
        ])
        XCTAssertEqual(
            LinePlan.completeDiagram(
                for: Array(detail.directions.reversed()),
                disruptions: detail.disruptions
            ),
            viewModel.diagram
        )
    }
}
