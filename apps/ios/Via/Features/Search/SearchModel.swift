import Foundation
import Observation

enum SearchState: Equatable, Sendable {
    case idle
    case loading(previous: [SearchResult])
    case ready(results: [SearchResult], banUnavailable: Bool)
    case failed(previous: [SearchResult])

    var results: [SearchResult] {
        switch self {
        case .idle: []
        case .loading(let previous), .failed(let previous): previous
        case .ready(let results, _): results
        }
    }
}

@MainActor
@Observable
final class SearchModel {
    let transitAPI: any TransitAPI
    let locationProvider: any LocationProviding
    let clock: any ViaClock

    var query = ""
    var state: SearchState = .idle

    private var task: Task<Void, Never>?

    init(
        transitAPI: any TransitAPI,
        locationProvider: any LocationProviding,
        clock: any ViaClock = SystemViaClock()
    ) {
        self.transitAPI = transitAPI
        self.locationProvider = locationProvider
        self.clock = clock
    }

    func setQuery(_ query: String) {
        self.query = query
        task?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            return
        }

        let previous = state.results
        state = .loading(previous: previous)
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await clock.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                let response = try await transitAPI.search(
                    query: trimmed,
                    near: locationProvider.coordinate
                )
                guard !Task.isCancelled,
                      query.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed
                else { return }
                state = .ready(
                    results: response.results,
                    banUnavailable: response.sources.ban == .unavailable
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(previous: previous)
            }
        }
    }

    func retry() {
        setQuery(query)
    }
}
