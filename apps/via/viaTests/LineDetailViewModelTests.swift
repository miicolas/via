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
    func testTheCompletePlanUsesTheRichestDirectionAsItsStableReference() async {
        let viewModel = await makeViewModel(detail: PreviewLineStatusRepository.rerADetail)

        // Direction 1 of the fixture is a stub. The richer direction fixes the
        // stable orientation, but the plan remains a union of every direction
        // rather than a copy of that direction alone.
        XCTAssertEqual(viewModel.diagram.sections.map(\.role), [
            .main,
            .branch(name: "Saint-Germain-en-Laye", junction: "Nanterre-Préfecture"),
            .branch(name: "Cergy-le-Haut", junction: "Sartrouville"),
            .branch(name: "Poissy", junction: "Sartrouville"),
            .branch(name: "Marne-la-Vallée – Chessy", junction: "Vincennes"),
            .branch(name: "Boissy-St-Léger", junction: "Vincennes"),
        ])
        XCTAssertEqual(viewModel.diagram.sections.map { $0.stops.map(\.stop.name) }, [
            [
                "Sartrouville", "Maisons-Laffitte", "Nanterre-Préfecture", "La Défense",
                "Auber", "Châtelet — Les Halles", "Gare de Lyon", "Nation", "Vincennes",
            ],
            ["Le Vésinet — Le Pecq", "Saint-Germain-en-Laye"],
            ["Conflans-Fin-d'Oise", "Cergy-le-Haut"],
            ["Achères-Ville", "Poissy"],
            [
                "Val de Fontenay", "Noisy-le-Grand — Mont d'Est", "Val d'Europe",
                "Marne-la-Vallée – Chessy",
            ],
            ["Joinville-le-Pont", "Boissy-St-Léger"],
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
            "Cergy-le-Haut",
            "Poissy",
            "Marne-la-Vallée – Chessy",
            "Boissy-St-Léger",
        ])
        XCTAssertEqual(branchNames.count, 5)

        let stationIDs = viewModel.diagram.sections.flatMap { $0.stops.map(\.stop.id) }
        XCTAssertEqual(stationIDs.count, Set(stationIDs).count)
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

        let diagram = LinePlan.diagram(for: [direction], disruptions: [])
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
            LinePlan.diagram(
                for: Array(detail.directions.reversed()),
                disruptions: detail.disruptions
            ),
            viewModel.diagram
        )
    }
}
