import XCTest
@testable import Via

@MainActor
final class SearchViewModelTests: XCTestCase {
    func testFlowDefaultsToCurrentLocationAndKeepsTheQueryOrder() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let destination = SearchResult.previewStation
        let model = SearchViewModel(
            repository: InMemorySearchRepository.preview,
            now: { now }
        )

        XCTAssertEqual(model.selectedDeparture, .currentLocation)
        XCTAssertEqual(model.subtitle, "Depuis Ma position")

        model.selectDestination(destination)

        XCTAssertEqual(model.step, .date)
        XCTAssertEqual(model.selectedDestination, destination)
        XCTAssertEqual(model.selectedDate, Calendar.current.startOfDay(for: now))
        XCTAssertFalse(model.isDateConfirmed)

        let date = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        model.confirmDate(date)

        XCTAssertEqual(model.step, .ready)
        XCTAssertTrue(model.isDateConfirmed)
        XCTAssertEqual(model.selectedDate, date)
        XCTAssertEqual(
            model.searchQuery,
            SearchQuery(
                destination: destination,
                date: date,
                departure: .currentLocation
            )
        )
    }

    func testEditingDestinationResetsTheLaterSteps() {
        let model = SearchViewModel(repository: InMemorySearchRepository.preview)
        model.selectDestination(.previewStation)
        model.confirmDate(.now)

        model.editDestination()

        XCTAssertEqual(model.step, .destination)
        XCTAssertNil(model.selectedDestination)
        XCTAssertNil(model.selectedDate)
        XCTAssertEqual(model.selectedDeparture, .currentLocation)
        XCTAssertFalse(model.isDateConfirmed)
    }

    func testOriginCanBeChangedFromTheTitleMenuBeforeTheDateIsConfirmed() {
        let model = SearchViewModel(repository: InMemorySearchRepository.preview)

        model.selectDeparture(.saved(.home))

        XCTAssertEqual(model.selectedDeparture, .saved(.home))
        XCTAssertEqual(model.subtitle, "Depuis Maison")
        XCTAssertEqual(model.step, .destination)

        model.selectDeparture(.currentLocation)

        XCTAssertEqual(model.selectedDeparture, .currentLocation)
        XCTAssertEqual(model.subtitle, "Depuis Ma position")
    }

    func testSubmittingAReadySearchShowsNoResultsAndEditingPreservesTheQuery() {
        let destination = SearchResult.previewStation
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let model = SearchViewModel(repository: InMemorySearchRepository.preview)
        model.selectDestination(destination)
        model.confirmDate(date)

        let submittedQuery = model.submitSearch()

        XCTAssertEqual(
            submittedQuery,
            SearchQuery(
                destination: destination,
                date: date,
                departure: .currentLocation
            )
        )
        XCTAssertEqual(model.step, .noResults)

        model.editSubmittedSearch()

        XCTAssertEqual(model.step, .ready)
        XCTAssertEqual(model.selectedDestination, destination)
        XCTAssertEqual(model.selectedDate, date)
        XCTAssertEqual(model.selectedDeparture, .currentLocation)
    }

    func testQuerySearchPublishesResultsAfterDebounce() async {
        let model = SearchViewModel(repository: InMemorySearchRepository.preview)

        model.updateQuery("cha")

        for _ in 0..<100 {
            if model.loadState == .loaded { break }
            try? await Task.sleep(for: .milliseconds(5))
        }

        XCTAssertEqual(model.loadState, .loaded)
        XCTAssertEqual(model.results, [.previewStation, .previewAddress])
    }

    func testShortQueryDoesNotCallSearch() {
        let model = SearchViewModel(repository: InMemorySearchRepository.preview)

        model.updateQuery("c")

        XCTAssertEqual(model.loadState, .idle)
        XCTAssertTrue(model.results.isEmpty)
    }
}
