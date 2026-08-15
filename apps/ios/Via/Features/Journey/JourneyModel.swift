import Foundation
import Observation

@MainActor
@Observable
final class JourneyModel {
    let transitAPI: any TransitAPI

    private(set) var state: JourneyState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((JourneyState) -> Void)?

    private var task: Task<Void, Never>?
    private var request: JourneyRequest?
    private var generation = 0

    init(transitAPI: any TransitAPI) {
        self.transitAPI = transitAPI
    }

    func plan(to destination: JourneyDestination, from origin: GeoCoordinate) {
        plan(JourneyRequest(origin: origin, destination: destination))
    }

    @discardableResult
    func retry() -> Bool {
        guard let request else { return false }
        plan(request)
        return true
    }

    func adopt(request: JourneyRequest, response: JourneysResponse) {
        task?.cancel()
        generation += 1
        self.request = request
        state = .ready(request: request, response: response)
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        request = nil
        state = .idle
    }

    private func plan(_ request: JourneyRequest) {
        generation += 1
        let generation = generation
        task?.cancel()
        self.request = request
        state = .planning(request: request)
        task = Task { [weak self] in
            guard let self else { return }

            do {
                let response = try await transitAPI.planJourneys(request)
                guard !Task.isCancelled,
                      generation == self.generation,
                      self.request?.key == request.key
                else { return }
                state = .ready(request: request, response: response)
            } catch is CancellationError {
                return
            } catch {
                guard generation == self.generation, self.request?.key == request.key else { return }
                state = .failed(request: request)
            }
        }
    }
}
