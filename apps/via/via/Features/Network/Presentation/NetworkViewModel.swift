import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class NetworkViewModel {
    private(set) var state: Loadable<TransitNetwork> = .idle
    private(set) var viewport: StationsArea?
    var selectedRouteID: RouteID?

    @ObservationIgnored private let repository: any NetworkRepository
    @ObservationIgnored private var railTask: Task<Void, Never>?
    @ObservationIgnored private var viewportTask: Task<Void, Never>?

    init(repository: any NetworkRepository) { self.repository = repository }

    func load() {
        railTask?.cancel()
        let previous = state.value
        state = .loading(previous: previous)
        railTask = Task {
            do { state = .loaded(try await repository.railMap()) }
            catch is CancellationError { }
            catch { state = .failed(error.via, previous: previous) }
        }
    }

    func viewportChanged(to bounds: GeoBounds) {
        viewportTask?.cancel()
        viewportTask = Task {
            do {
                let area = try await repository.viewport(in: bounds)
                try Task.checkCancellation()
                viewport = area
            } catch is CancellationError { }
            catch {
                ViaLog.network.error("Viewport failed: \(String(describing: error), privacy: .private(mask: .hash))")
            }
        }
    }
}
