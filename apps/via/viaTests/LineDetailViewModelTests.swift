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
    func testThePlanIsDrawnFromTheRichestDirection() async {
        let viewModel = await makeViewModel(detail: PreviewLineStatusRepository.rerADetail)

        // Direction 1 of the fixture is a stub; the plan takes the complete one.
        XCTAssertEqual(viewModel.detail.value?.planDirection?.id, "direction-0")
        XCTAssertEqual(viewModel.strips.filter { $0.role == .trunk }.count, 1)
        XCTAssertEqual(
            viewModel.strips.compactMap(\.role.name),
            [
                "Saint-Germain-en-Laye",
                "Cergy-le-Haut",
                "Poissy",
                "Marne-la-Vallée – Chessy",
                "Boissy-St-Léger",
            ]
        )
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

        XCTAssertEqual(viewModel.detail.value?.planDirection?.id, "branch-p-m1-0")
        XCTAssertEqual(viewModel.strips.flatMap { $0.stops.map(\.stop.id) }, ["a", "b"])
    }

    @MainActor
    func testTheTrunkIsAlwaysOpenAndABranchTogglesOnTap() async {
        let viewModel = await makeViewModel(detail: PreviewLineStatusRepository.rerADetail)

        guard let trunk = viewModel.strips.first(where: { $0.role == .trunk }),
              let healthy = viewModel.strips.first(where: { $0.role.isBranch && $0.condition == nil })
        else { return XCTFail("expected a trunk and a healthy branch") }

        XCTAssertTrue(viewModel.isOpen(trunk))
        XCTAssertFalse(viewModel.isOpen(healthy))

        viewModel.toggle(healthy)
        XCTAssertTrue(viewModel.isOpen(healthy))

        viewModel.toggle(healthy)
        XCTAssertFalse(viewModel.isOpen(healthy))
    }

    @MainActor
    func testADisruptedBranchOpensByItself() async {
        let viewModel = await makeViewModel(detail: PreviewLineStatusRepository.rerADetail)

        guard let cut = viewModel.strips.first(where: { $0.condition != nil && $0.role.isBranch })
        else { return XCTFail("the fixture cuts the Marne-la-Vallée branch") }

        XCTAssertEqual(cut.role.name, "Marne-la-Vallée – Chessy")
        XCTAssertTrue(viewModel.isOpen(cut))
    }
}
