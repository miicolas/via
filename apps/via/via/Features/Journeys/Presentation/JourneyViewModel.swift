import Foundation
import Observation

@MainActor
@Observable
final class JourneyViewModel {
    private(set) var state: Loadable<JourneyResult> = .idle
    private(set) var request: JourneyRequest?

    @ObservationIgnored private let repository: any JourneyRepository
    @ObservationIgnored private var task: Task<Void, Never>?

    init(repository: any JourneyRepository) { self.repository = repository }

    func plan(_ request: JourneyRequest) {
        task?.cancel()
        self.request = request
        let previous = state.value
        state = .loading(previous: previous)
        task = Task {
            do { state = .loaded(try await repository.plan(request)) }
            catch is CancellationError { }
            catch { state = .failed(error.via, previous: previous) }
        }
    }

    func retry() {
        guard let request else { return }
        plan(request)
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
