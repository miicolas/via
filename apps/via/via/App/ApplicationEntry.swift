import SwiftUI

@main
@MainActor
struct ApplicationEntry: App {
    @State private var locationModel: LocationModel
    @State private var networkViewModel: NetworkViewModel
    @State private var stationsViewModel: StationsViewModel
    @State private var linesViewModel: LinesViewModel
    @State private var accountModel: AccountModel
    @State private var authSessionViewModel: AuthSessionViewModel
    private let searchRepository: any SearchRepository
    private let journeyRepository: any JourneyRepository
    private let lineStatusRepository: any LineStatusRepository

    init() {
        let dependencies = Self.makeDependencies()
        _locationModel = State(initialValue: dependencies.locationModel)
        _networkViewModel = State(
            initialValue: NetworkViewModel(repository: dependencies.networkRepository)
        )
        _stationsViewModel = State(
            initialValue: StationsViewModel(
                locationModel: dependencies.locationModel,
                networkRepository: dependencies.networkRepository,
                departuresRepository: dependencies.departuresRepository
            )
        )
        _linesViewModel = State(
            initialValue: LinesViewModel(repository: dependencies.lineStatusRepository)
        )
        _accountModel = State(initialValue: dependencies.accountModel)
        _authSessionViewModel = State(initialValue: dependencies.authSessionViewModel)
        searchRepository = dependencies.searchRepository
        journeyRepository = dependencies.journeyRepository
        lineStatusRepository = dependencies.lineStatusRepository
    }

    var body: some Scene {
        WindowGroup {
            MapShellView(
                networkViewModel: networkViewModel,
                stationsViewModel: stationsViewModel,
                linesViewModel: linesViewModel,
                locationModel: locationModel,
                accountModel: accountModel,
                searchRepository: searchRepository,
                journeyRepository: journeyRepository,
                lineStatusRepository: lineStatusRepository
            )
            .task {
                await authSessionViewModel.restore()
            }
        }
    }

    private static func makeDependencies() -> Dependencies {
        guard let configuration = try? AppConfiguration.bundled() else {
            let accountModel = AccountModel(
                remote: InMemoryAccountRemote(),
                synchronizationEnabled: false
            )
            let previewSession = StoredAuthSession(
                bearerToken: "preview.token",
                user: AuthUser(
                    id: "preview",
                    appleUserIdentifier: "preview",
                    name: "Preview",
                    email: "preview@example.com"
                ),
                expiresAt: .distantFuture,
                lastValidatedAt: .now
            )

            return Dependencies(
                locationModel: LocationModel(
                    adapter: InMemoryLocationAdapter(
                        coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470)
                    )
                ),
                networkRepository: InMemoryNetworkRepository.mapPreview,
                departuresRepository: InMemoryDeparturesRepository.stationsPreview,
                searchRepository: InMemorySearchRepository.preview,
                journeyRepository: PreferenceAwareJourneyRepository(
                    base: InMemoryJourneyRepository(result: .mapPreview),
                    account: accountModel
                ),
                lineStatusRepository: PreviewLineStatusRepository(),
                accountModel: accountModel,
                authSessionViewModel: AuthSessionViewModel(
                    client: InMemoryAuthenticationClient(session: previewSession),
                    vault: InMemoryAuthSessionVault(),
                    account: accountModel
                )
            )
        }

        // The network endpoints are public; unauthorized responses keep the default no-op handler.
        let authSessionVault = KeychainAuthSessionVault(apiBaseURL: configuration.apiBaseURL)
        let transport = APITransport(
            baseURL: configuration.apiBaseURL,
            authSessionVault: authSessionVault
        )
        let accountModel = AccountModel(remote: LiveAccountRemote(transport: transport))
        let journeyRepository = PreferenceAwareJourneyRepository(
            base: LiveJourneyRepository(transport: transport),
            account: accountModel
        )

        return Dependencies(
            locationModel: LocationModel(adapter: CoreLocationAdapter()),
            networkRepository: LiveNetworkRepository(transport: transport),
            departuresRepository: LiveDeparturesRepository(transport: transport),
            searchRepository: LiveSearchRepository(transport: transport),
            journeyRepository: journeyRepository,
            lineStatusRepository: LiveLineStatusRepository(transport: transport),
            accountModel: accountModel,
            authSessionViewModel: AuthSessionViewModel(
                client: BetterAuthClient(baseURL: configuration.apiBaseURL),
                vault: authSessionVault,
                account: accountModel
            )
        )
    }

    private struct Dependencies {
        let locationModel: LocationModel
        let networkRepository: any NetworkRepository
        let departuresRepository: any DeparturesRepository
        let searchRepository: any SearchRepository
        let journeyRepository: any JourneyRepository
        let lineStatusRepository: any LineStatusRepository
        let accountModel: AccountModel
        let authSessionViewModel: AuthSessionViewModel
    }
}
