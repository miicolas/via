import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class NetworkViewModel {
    private(set) var state: Loadable<TransitNetwork> = .idle
    private(set) var stationMapItems: [StationMapItem] = []
    private(set) var routeLayout: TransitRouteLayout?
    private(set) var routeLayoutRevision = 0
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
            do {
                let network = try await repository.railMap()
                let layout = await Task.detached(priority: .userInitiated) {
                    TransitRouteLayout(routes: network.routes)
                }.value
                try Task.checkCancellation()
                routeLayout = layout
                routeLayoutRevision &+= 1
                state = .loaded(network)
                ViaLog.network.debug("Rail map loaded with \(network.routes.count, privacy: .public) routes")
            }
            catch is CancellationError { }
            catch {
                state = .failed(error.via, previous: previous)
                ViaLog.network.error(
                    "Rail map failed: \(String(describing: error), privacy: .private(mask: .hash))"
                )
            }
        }
    }

    func viewportChanged(to bounds: GeoBounds) {
        viewportTask?.cancel()
        viewportTask = Task {
            do {
                let area = try await repository.viewport(in: bounds)
                try Task.checkCancellation()
                stationMapItems = area.mapItems
            } catch is CancellationError { }
            catch {
                ViaLog.network.error("Viewport failed: \(String(describing: error), privacy: .private(mask: .hash))")
            }
        }
    }
}
