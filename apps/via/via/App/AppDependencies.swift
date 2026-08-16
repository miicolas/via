import Foundation

@MainActor
struct AppDependencies {
    let authSession: AuthSessionViewModel
    let account: AccountModel
    let network: any NetworkRepository
    let search: any SearchRepository
    let departures: any DeparturesRepository
    let journeys: any JourneyRepository
    let naturalJourneys: any NaturalJourneyRepository
    let chat: any ChatRepository
    let location: () -> any LocationAdapter

    static func live(configuration: AppConfiguration) throws -> AppDependencies {
        let vault = KeychainAuthSessionVault()
        let lifecycle = AsyncStream.makeStream(of: AuthLifecycleEvent.self)
        let transport = ViaTransport(
            baseURL: configuration.apiBaseURL,
            authSessionVault: vault,
            onUnauthorized: {
                lifecycle.continuation.yield(.authenticatedRequestRejected)
            }
        )
        let accountRemote = LiveAccountRemote(transport: transport)
        let accountStore = AccountLocalStore()
        let account = AccountModel(store: accountStore, remote: accountRemote)
        let search = LiveSearchRepository(transport: transport)
        let journeys = PreferenceAwareJourneyRepository(
            base: LiveJourneyRepository(transport: transport),
            account: account
        )
        return AppDependencies(
            authSession: AuthSessionViewModel(
                client: BetterAuthClient(baseURL: configuration.apiBaseURL),
                vault: vault,
                account: account,
                lifecycleEvents: lifecycle.stream
            ),
            account: account,
            network: LiveNetworkRepository(transport: transport),
            search: search,
            departures: LiveDeparturesRepository(transport: transport),
            journeys: journeys,
            naturalJourneys: LiveNaturalJourneyRepository(transport: transport),
            chat: FoundationModelsChatRepository(
                search: { try await search.search(query: $0, near: $1) },
                plan: { try await journeys.plan($0) }
            ),
            location: { CoreLocationAdapter() }
        )
    }

    static var preview: AppDependencies {
        let vault = InMemoryAuthSessionVault()
        let baseURL = URL(string: "https://example.com/api")!
        let accountRemote = InMemoryAccountRemote()
        let defaults = UserDefaults(suiteName: "dev.via.preview")!
        let accountStore = AccountLocalStore(defaults: defaults)
        let account = AccountModel(
            store: accountStore,
            remote: accountRemote,
            synchronizationEnabled: false
        )
        return AppDependencies(
            authSession: AuthSessionViewModel(
                client: BetterAuthClient(baseURL: baseURL),
                vault: vault,
                account: account
            ),
            account: account,
            network: InMemoryNetworkRepository(),
            search: InMemorySearchRepository(),
            departures: InMemoryDeparturesRepository(),
            journeys: InMemoryJourneyRepository(),
            naturalJourneys: InMemoryNaturalJourneyRepository(),
            chat: InMemoryChatRepository(),
            location: { InMemoryLocationAdapter() }
        )
    }

    func makeNetworkViewModel() -> NetworkViewModel { NetworkViewModel(repository: network) }
    func makeSearchViewModel() -> SearchViewModel { SearchViewModel(repository: search, account: account) }
    func makeDeparturesViewModel(stationID: StationID) -> DeparturesViewModel {
        DeparturesViewModel(stationID: stationID, repository: departures)
    }
    func makeJourneyViewModel() -> JourneyViewModel { JourneyViewModel(repository: journeys) }
    func makeNaturalJourneyViewModel() -> NaturalJourneyViewModel { NaturalJourneyViewModel(repository: naturalJourneys) }
    func makeChatViewModel() -> ChatViewModel { ChatViewModel(repository: chat) }
    func makeLocationViewModel() -> LocationViewModel { LocationViewModel(adapter: location()) }
}
