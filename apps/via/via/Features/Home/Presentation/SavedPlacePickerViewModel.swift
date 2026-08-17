import Foundation
import Observation

@MainActor
@Observable
final class SavedPlacePickerViewModel {
    private(set) var search: PlaceSearchState = .idle
    /// Geographic anchor used to rank results by proximity; set by the view.
    var anchor: GeoCoordinate?

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }

    @ObservationIgnored private let repository: any SearchRepository
    @ObservationIgnored private let delay: Duration
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var revision = 0

    init(repository: any SearchRepository, delay: Duration = .milliseconds(400)) {
        self.repository = repository
        self.delay = delay
    }

    func retry() {
        scheduleSearch(delay: .zero)
    }

    private func scheduleSearch(delay: Duration? = nil) {
        revision &+= 1
        task?.cancel()
        task = nil

        let sanitized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            search = .idle
            return
        }

        let revision = revision
        let previous = search.visibleResponse
        let anchor = anchor
        search = .debouncing(previous: previous)
        task = Task { [weak self, repository] in
            guard let self else { return }
            do {
                try await Task.sleep(for: delay ?? self.delay)
                guard revision == self.revision else { return }
                search = .loading(previous: previous)
                let response = try await repository.search(query: sanitized, near: anchor)
                try Task.checkCancellation()
                guard revision == self.revision else { return }
                search = response.results.isEmpty
                    ? .empty(addressSource: response.addressSource)
                    : .loaded(response)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, revision == self.revision else { return }
                search = .failed(error.via, previous: previous)
            }
        }
    }
}
