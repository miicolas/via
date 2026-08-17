import XCTest
@testable import Via

@MainActor
final class LineStatusTests: XCTestCase {
    func testPreviewLoadsAndSortsDisruptionsFirst() async {
        let model = LinesViewModel(repository: PreviewLineStatusRepository())

        await model.load()

        XCTAssertEqual(model.visibleStatuses.first?.condition, .suspended)
        XCTAssertTrue(model.visibleStatuses.contains { $0.condition == .disrupted })
    }

    func testDisruptionFilterHidesNormalLines() async {
        let model = LinesViewModel(repository: PreviewLineStatusRepository())
        await model.load()
        model.disruptionsOnly = true

        XCTAssertFalse(model.visibleStatuses.isEmpty)
        XCTAssertTrue(model.visibleStatuses.allSatisfy { $0.condition != .normal })
    }

    func testNativeFilterDimensionsComeFromFixtures() async {
        let model = LinesViewModel(repository: PreviewLineStatusRepository())
        await model.load()
        model.selectedMode = .metro

        XCTAssertEqual(model.networks, ["Île-de-France"])
        XCTAssertTrue(model.directions.contains("Porte de Clignancourt"))
        XCTAssertTrue(model.visibleStatuses.allSatisfy { $0.mode == .metro })
    }

    func testUniversalSearchMatchesLineNameAndAffectedStop() {
        let line = PreviewLineStatusRepository.defaultStatuses[0]

        XCTAssertTrue(line.matchesSearch("metro 4"))
        XCTAssertTrue(line.matchesSearch("Gare du Nord"))
        XCTAssertFalse(line.matchesSearch("ligne inconnue"))
    }

    func testRepositoryErrorIsRepresentedAsFailedState() async {
        let model = LinesViewModel(repository: FailingLineStatusRepository())

        await model.load()

        guard case .failed(.unavailable, previous: nil) = model.statuses else {
            return XCTFail("Expected an unavailable line state")
        }
    }
}

private struct FailingLineStatusRepository: LineStatusRepository {
    func loadStatuses() async throws -> [LineStatus] {
        throw ViaError.unavailable
    }
}
