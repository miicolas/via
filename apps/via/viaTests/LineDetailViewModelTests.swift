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
        XCTAssertEqual(viewModel.diagram.sections.count, 7)
        XCTAssertEqual(viewModel.diagram.sections.map(\.lane), [0, 1, 2, 1, 0, 0, 1])
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
}
