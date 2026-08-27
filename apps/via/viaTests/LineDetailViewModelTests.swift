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
                "Cergy-le-Haut / Poissy",
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
    func testTheCompletePlanIncludesHealthyAndDisruptedBranches() async {
        let viewModel = await makeViewModel(detail: PreviewLineStatusRepository.rerADetail)

        XCTAssertTrue(viewModel.strips.contains { $0.role.isBranch && $0.condition == nil })
        XCTAssertEqual(
            viewModel.strips.first { $0.condition != nil && $0.role.isBranch }?.role.name,
            "Marne-la-Vallée – Chessy"
        )
    }
}
