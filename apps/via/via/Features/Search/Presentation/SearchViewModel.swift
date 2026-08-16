import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum State: Sendable, Equatable {
        case idle(recent: [RecentSearch])
        case debouncing(previous: SearchResponse?)
        case loading(previous: SearchResponse?)
        case loaded(SearchResponse)
        case empty(addressSource: SearchResponse.AddressSource)
        case failed(ViaError, previous: SearchResponse?)
    }

    var query = "" { didSet { scheduleSearch() } }
    private(set) var state: State

    @ObservationIgnored private let repository: any SearchRepository
    @ObservationIgnored private let recents: any RecentSearchRepository
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var location: GeoCoordinate?

    init(repository: any SearchRepository, recents: any RecentSearchRepository) {
        self.repository = repository
        self.recents = recents
        state = .idle(recent: recents.load())
    }

    func updateLocation(_ location: GeoCoordinate?) {
        self.location = location
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { scheduleSearch() }
    }

    func select(_ result: SearchResult) {
        let search = RecentSearch(result: result)
        let history = [search] + recents.load().filter { $0.id != search.id }
        recents.store(Array(history.prefix(5)))
    }

    func clearRecents() {
        recents.clear()
        if query.isEmpty { state = .idle(recent: []) }
    }

    func retry() { scheduleSearch(delay: .zero) }

    private func scheduleSearch(delay: Duration = .milliseconds(600)) {
        task?.cancel()
        let sanitized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            state = .idle(recent: recents.load())
            return
        }
        let previous = state.response
        state = .debouncing(previous: previous)
        task = Task {
            do {
                try await Task.sleep(for: delay)
                state = .loading(previous: previous)
                let response = try await repository.search(query: sanitized, near: location)
                try Task.checkCancellation()
                state = response.results.isEmpty ? .empty(addressSource: response.addressSource) : .loaded(response)
            } catch is CancellationError { }
            catch {
                guard !Task.isCancelled else { return }
                state = .failed(error.via, previous: previous)
            }
        }
    }
}

private extension SearchViewModel.State {
    var response: SearchResponse? {
        switch self {
        case .loaded(let response): response
        case .debouncing(let previous), .loading(let previous), .failed(_, let previous): previous
        case .idle, .empty: nil
        }
    }
}
