import SwiftUI

@main
@MainActor
struct ApplicationEntry: App {
    @State private var networkViewModel: NetworkViewModel
    @State private var stationsViewModel: StationsViewModel
    @State private var linesViewModel: LinesViewModel
    private let searchRepository: any SearchRepository
    private let lineStatusRepository: any LineStatusRepository

    init() {
        let dependencies = Self.makeDependencies()
        _networkViewModel = State(
            initialValue: NetworkViewModel(repository: dependencies.networkRepository)
        )
        _stationsViewModel = State(
            initialValue: StationsViewModel(
                locationAdapter: dependencies.locationAdapter,
                networkRepository: dependencies.networkRepository,
                departuresRepository: dependencies.departuresRepository
            )
        )
        _linesViewModel = State(
            initialValue: LinesViewModel(repository: dependencies.lineStatusRepository)
        )
        searchRepository = dependencies.searchRepository
        lineStatusRepository = dependencies.lineStatusRepository
    }

    var body: some Scene {
        WindowGroup {
            MapShellView(
                networkViewModel: networkViewModel,
                stationsViewModel: stationsViewModel,
                linesViewModel: linesViewModel,
                searchRepository: searchRepository,
                lineStatusRepository: lineStatusRepository
            )
        }
    }

    private static func makeDependencies() -> Dependencies {
        guard let configuration = try? AppConfiguration.bundled() else {
            return Dependencies(
                locationAdapter: InMemoryLocationAdapter(
                    coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470)
                ),
                networkRepository: InMemoryNetworkRepository.mapPreview,
                departuresRepository: InMemoryDeparturesRepository.stationsPreview,
                searchRepository: InMemorySearchRepository.preview,
                lineStatusRepository: PreviewLineStatusRepository()
            )
        }

        // The network endpoints are public; unauthorized responses keep the default no-op handler.
        let transport = APITransport(
            baseURL: configuration.apiBaseURL,
            authSessionVault: KeychainAuthSessionVault(apiBaseURL: configuration.apiBaseURL)
        )
        let networkRepository = LiveNetworkRepository(transport: transport)

        return Dependencies(
            locationAdapter: CoreLocationAdapter(),
            networkRepository: networkRepository,
            departuresRepository: LiveDeparturesRepository(transport: transport),
            searchRepository: LiveSearchRepository(transport: transport),
            lineStatusRepository: LiveLineStatusRepository(transport: transport)
        )
    }

    private struct Dependencies {
        let locationAdapter: any LocationAdapter
        let networkRepository: any NetworkRepository
        let departuresRepository: any DeparturesRepository
        let searchRepository: any SearchRepository
        let lineStatusRepository: any LineStatusRepository
    }
}
