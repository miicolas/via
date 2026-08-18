import Foundation
import Observation

enum SearchViewStep: Int, Sendable, Equatable {
    case destination
    case date
    case departure
    case ready
    case noResults
}

enum SearchLoadState: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(ViaError)
}

enum SearchDepartureSelection: Sendable, Hashable {
    case currentLocation
    case saved(StationPlaceShortcut)
    case manual(SearchResult)

    var title: String {
        switch self {
        case .currentLocation:
            "Ma position"
        case .saved(let shortcut):
            shortcut.title
        case .manual(let result):
            result.name
        }
    }

    var subtitle: String? {
        switch self {
        case .currentLocation:
            "Position actuelle"
        case .saved:
            "Lieu enregistré"
        case .manual(let result):
            result.departureSearchSubtitle
        }
    }
}

struct SearchQuery: Sendable, Hashable {
    let destination: SearchResult
    let date: Date
    let departure: SearchDepartureSelection
}

@MainActor
@Observable
final class SearchViewModel {
    private(set) var step: SearchViewStep = .destination
    private(set) var results: [SearchResult] = []
    private(set) var loadState: SearchLoadState = .idle
    private(set) var selectedDestination: SearchResult?
    private(set) var selectedDate: Date?
    private(set) var selectedDeparture: SearchDepartureSelection? = .currentLocation
    private(set) var isDateConfirmed = false

    var query = ""

    @ObservationIgnored private let repository: any SearchRepository
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var lastSearchedQuery = ""

    init(
        repository: any SearchRepository,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.repository = repository
        self.now = now
    }

    var subtitle: String {
        "Depuis \(selectedDeparture?.title ?? "Ma position")"
    }

    var suggestedDate: Date {
        Calendar.current.startOfDay(for: now())
    }

    var searchQuery: SearchQuery? {
        guard let selectedDestination,
              let selectedDate,
              let selectedDeparture,
              isDateConfirmed else {
            return nil
        }

        return SearchQuery(
            destination: selectedDestination,
            date: selectedDate,
            departure: selectedDeparture
        )
    }

    func updateQuery(_ value: String) {
        guard step == .destination else { return }

        query = value
        searchTask?.cancel()

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else {
            results = []
            loadState = .idle
            lastSearchedQuery = ""
            return
        }

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }

            guard !Task.isCancelled, let self else { return }
            await self.performSearch(normalized)
        }
    }

    func searchImmediately() {
        guard step == .destination else { return }

        searchTask?.cancel()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else { return }

        searchTask = Task { [weak self] in
            guard !Task.isCancelled, let self else { return }
            await self.performSearch(normalized)
        }
    }

    func retry() {
        let retryQuery = lastSearchedQuery.isEmpty
            ? query.trimmingCharacters(in: .whitespacesAndNewlines)
            : lastSearchedQuery

        guard retryQuery.count >= 2 else { return }
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard !Task.isCancelled, let self else { return }
            await self.performSearch(retryQuery)
        }
    }

    func clearQuery() {
        updateQuery("")
    }

    func selectDestination(_ result: SearchResult) {
        searchTask?.cancel()
        selectedDestination = result
        query = ""
        results = []
        loadState = .idle
        selectedDate = suggestedDate
        isDateConfirmed = false
        step = .date
    }

    func editDestination() {
        selectedDestination = nil
        selectedDate = nil
        isDateConfirmed = false
        query = ""
        results = []
        loadState = .idle
        step = .destination
    }

    func confirmDate(_ date: Date) {
        guard selectedDestination != nil else { return }

        selectedDate = date
        isDateConfirmed = true
        selectedDeparture = selectedDeparture ?? .currentLocation
        step = .ready
    }

    func editDate() {
        guard selectedDestination != nil else { return }

        isDateConfirmed = false
        step = .date
    }

    func selectDeparture(_ departure: SearchDepartureSelection) {
        selectedDeparture = departure
        if selectedDestination != nil, isDateConfirmed {
            step = .ready
        }
    }

    func editDeparture() {
        guard selectedDestination != nil, isDateConfirmed else { return }

        selectedDeparture = .currentLocation
        step = .ready
    }

    func submitSearch() -> SearchQuery? {
        guard let searchQuery else { return nil }
        step = .noResults
        return searchQuery
    }

    func editSubmittedSearch() {
        guard step == .noResults, searchQuery != nil else { return }
        step = .ready
    }

    private func performSearch(_ normalizedQuery: String) async {
        loadState = .loading
        lastSearchedQuery = normalizedQuery

        do {
            let response = try await repository.search(query: normalizedQuery, near: nil)
            guard !Task.isCancelled else { return }

            results = response.results
            loadState = response.results.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            loadState = .failed(error.via)
        }
    }
}

private extension SearchResult {
    var departureSearchSubtitle: String? {
        switch self {
        case .station(let station):
            guard !station.routes.isEmpty else { return "Station" }
            return station.routes
                .prefix(3)
                .map(\.shortName)
                .joined(separator: " · ")
        case .address(let address):
            return address.context.isEmpty ? "Adresse" : address.context
        }
    }
}
