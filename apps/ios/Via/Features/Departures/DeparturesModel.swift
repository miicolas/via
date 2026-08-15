import Foundation
import Observation

enum DeparturesState: Equatable, Sendable {
    case idle
    case loading
    case ready(response: DeparturesResponse, stale: Bool)
    case failed

    var response: DeparturesResponse? {
        if case .ready(let response, _) = self { return response }
        return nil
    }
}

@MainActor
@Observable
final class DeparturesModel {
    let transitAPI: any TransitAPI
    let clock: any ViaClock

    private(set) var state: DeparturesState = .idle

    private var task: Task<Void, Never>?
    private var stationID: String?
    private var generation = 0

    init(transitAPI: any TransitAPI, clock: any ViaClock = SystemViaClock()) {
        self.transitAPI = transitAPI
        self.clock = clock
    }

    func start(for stationID: String) {
        guard !stationID.isEmpty else { return }

        let sameStation = self.stationID == stationID
        self.stationID = stationID
        generation += 1
        let generation = generation
        task?.cancel()
        if !sameStation || state == .idle {
            state = .loading
        }

        task = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    let response = try await transitAPI.loadDepartures(stationID: stationID)
                    guard !Task.isCancelled,
                          generation == self.generation,
                          self.stationID == stationID
                    else { return }
                    state = .ready(response: response, stale: false)
                } catch is CancellationError {
                    return
                } catch {
                    guard generation == self.generation, self.stationID == stationID else { return }
                    if let response = state.response {
                        state = .ready(response: response, stale: true)
                    } else {
                        state = .failed
                    }
                }

                do {
                    try await clock.sleep(for: .seconds(60))
                } catch {
                    return
                }
            }
        }
    }

    func stopPolling() {
        task?.cancel()
        task = nil
    }

    func reset() {
        generation += 1
        stopPolling()
        stationID = nil
        state = .idle
    }
}
