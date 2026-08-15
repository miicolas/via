import Foundation
import Observation

@MainActor
@Observable
final class TransitNetworkModel {
    let transitAPI: any TransitAPI

    private(set) var railMap: RailMap?
    private(set) var state: NetworkState = .loading
    var onReady: (() -> Void)?

    private var task: Task<Void, Never>?
    private var loadGeneration = 0

    init(transitAPI: any TransitAPI) {
        self.transitAPI = transitAPI
    }

    var routes: [NetworkRoute] {
        railMap?.routes.sortedForDisplay ?? []
    }

    var stations: [NetworkStation] {
        railMap?.stations ?? []
    }

    func loadNetwork() {
        guard task == nil, state != .ready else { return }

        loadGeneration += 1
        let generation = loadGeneration
        state = .loading
        task = Task { [weak self] in
            guard let self else { return }

            do {
                let network = try await transitAPI.loadRailMap()
                guard !Task.isCancelled, generation == loadGeneration else { return }
                railMap = network
                state = network.routes.isEmpty ? .failed : .ready
                task = nil
                if state == .ready {
                    onReady?()
                }
            } catch is CancellationError {
                guard generation == loadGeneration else { return }
                task = nil
            } catch {
                guard !Task.isCancelled, generation == loadGeneration else { return }
                state = .failed
                task = nil
            }
        }
    }

    func reloadNetwork() {
        loadGeneration += 1
        task?.cancel()
        task = nil
        railMap = nil
        state = .loading
        loadNetwork()
    }
}
