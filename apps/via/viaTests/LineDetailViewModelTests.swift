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
    func testFirstDirectionIsSelectedByDefaultAndTheChoiceSticks() async {
        let viewModel = await makeViewModel(detail: PreviewLineStatusRepository.rerADetail)

        XCTAssertEqual(viewModel.selectedDirection?.id, "direction-0")

        viewModel.selectedDirectionID = "direction-1"
        XCTAssertEqual(
            viewModel.selectedDirection?.label,
            "Saint-Germain-en-Laye / Cergy-le-Haut / Poissy"
        )

        // A stale selection (direction gone after a refresh) falls back.
        viewModel.selectedDirectionID = "direction-9"
        XCTAssertEqual(viewModel.selectedDirection?.id, "direction-0")
    }

    @MainActor
    func testLegacyBranchesBackTheSchemaWhileDirectionsAreEmpty() async {
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

        XCTAssertEqual(viewModel.selectedDirection?.id, "branch-p-m1-0")
        XCTAssertEqual(viewModel.selectedDirection?.label, "Château de Vincennes")
        XCTAssertEqual(viewModel.schemaRows.map(\.id), ["a", "b"])
    }

    @MainActor
    func testToggleRunExpandsAndFoldsBack() async {
        let healthy = LineDetail(
            route: PreviewLineStatusRepository.metro1,
            branches: [],
            directions: [
                LineDirection(
                    id: "direction-0",
                    directionId: 0,
                    label: "Terminus",
                    sections: [
                        LineSchemaSection(
                            role: .trunk,
                            label: nil,
                            origins: ["a"],
                            termini: ["e"],
                            stops: ["a", "b", "c", "d", "e"].map {
                                LineSchemaStop(id: $0, name: $0, isInterchange: false)
                            }
                        )
                    ]
                )
            ],
            source: .live,
            fetchedAt: nil,
            disruptions: []
        )
        let viewModel = await makeViewModel(detail: healthy)

        let foldedIDs = viewModel.schemaRows.map(\.id)
        guard let runID = foldedIDs.first(where: { $0.hasPrefix("run-") }) else {
            return XCTFail("expected a folded run in the healthy schema")
        }

        viewModel.toggleRun(runID)
        XCTAssertFalse(viewModel.schemaRows.map(\.id).contains(runID))
        XCTAssertGreaterThan(viewModel.schemaRows.count, foldedIDs.count)

        viewModel.toggleRun(runID)
        XCTAssertEqual(viewModel.schemaRows.map(\.id), foldedIDs)
    }
}
