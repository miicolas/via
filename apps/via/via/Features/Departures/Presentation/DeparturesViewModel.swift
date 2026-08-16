import Foundation
import Observation

@MainActor
@Observable
final class DeparturesViewModel {
    private(set) var state: Loadable<DepartureBoard> = .idle

    @ObservationIgnored private let stationID: StationID
    @ObservationIgnored private let repository: any DeparturesRepository
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var isSceneActive = true

    init(stationID: StationID, repository: any DeparturesRepository) {
        self.stationID = stationID
        self.repository = repository
    }

    func start() {
        guard pollingTask == nil else { return }
        restartPolling()
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func setSceneActive(_ active: Bool) {
        isSceneActive = active
        if active, pollingTask != nil { restartPolling() }
    }

    func retry() { restartPolling() }

    private func restartPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                if isSceneActive { await refresh() }
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
            }
        }
    }

    private func refresh() async {
        let previous = state.value
        if previous == nil { state = .loading(previous: nil) }
        do { state = .loaded(try await repository.board(stationID: stationID)) }
        catch is CancellationError { }
        catch { state = .failed(error.via, previous: previous) }
    }
}
