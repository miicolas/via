import Foundation

@MainActor
struct AppDependencies {
    let authSession: AuthSessionViewModel
    let favoriteStations: any FavoriteStationRepository
    let transportPreferences: any TransportPreferencesRepository
    let network: any NetworkRepository
    let search: any SearchRepository
    let recentSearches: any RecentSearchRepository
    let departures: any DeparturesRepository
    let journeys: any JourneyRepository
    let naturalJourneys: any NaturalJourneyRepository
    let chat: any ChatRepository
    let location: () -> any LocationAdapter

    static func live(configuration: AppConfiguration) throws -> AppDependencies {
        let vault = KeychainAuthSessionVault()
        let client = LiveViaAPIClient(
            baseURL: configuration.apiBaseURL,
            authSessionVault: vault
        )
        let accountStore = AccountLocalStore()
        let accountSync = AccountSyncCoordinator(store: accountStore, client: client)
        let account = SyncedAccountRepository(store: accountStore, sync: accountSync)
        let search = LiveSearchRepository(client: client)
        let journeys = PreferenceAwareJourneyRepository(
            base: LiveJourneyRepository(client: client),
            preferences: account
        )
        return AppDependencies(
            authSession: AuthSessionViewModel(
                client: BetterAuthClient(baseURL: configuration.apiBaseURL),
                apiClient: client,
                vault: vault,
                accountStore: accountStore,
                accountSync: accountSync
            ),
            favoriteStations: account,
            transportPreferences: account,
            network: LiveNetworkRepository(client: client),
            search: search,
            recentSearches: account,
            departures: LiveDeparturesRepository(client: client),
            journeys: journeys,
            naturalJourneys: LiveNaturalJourneyRepository(client: client),
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
        let client = LiveViaAPIClient(baseURL: baseURL, authSessionVault: vault)
        let defaults = UserDefaults(suiteName: "dev.via.preview")!
        let accountStore = AccountLocalStore(defaults: defaults)
        let accountSync = AccountSyncCoordinator(store: accountStore, client: client)
        let account = SyncedAccountRepository(store: accountStore, sync: accountSync)
        return AppDependencies(
            authSession: AuthSessionViewModel(
                client: BetterAuthClient(baseURL: baseURL),
                apiClient: client,
                vault: vault,
                accountStore: accountStore,
                accountSync: accountSync
            ),
            favoriteStations: account,
            transportPreferences: account,
            network: InMemoryNetworkRepository(),
            search: InMemorySearchRepository(),
            recentSearches: InMemoryRecentSearchRepository(),
            departures: InMemoryDeparturesRepository(),
            journeys: InMemoryJourneyRepository(),
            naturalJourneys: InMemoryNaturalJourneyRepository(),
            chat: InMemoryChatRepository(),
            location: { InMemoryLocationAdapter() }
        )
    }

    func makeNetworkViewModel() -> NetworkViewModel { NetworkViewModel(repository: network) }
    func makeSearchViewModel() -> SearchViewModel { SearchViewModel(repository: search, recents: recentSearches) }
    func makeDeparturesViewModel(stationID: StationID) -> DeparturesViewModel {
        DeparturesViewModel(stationID: stationID, repository: departures)
    }
    func makeJourneyViewModel() -> JourneyViewModel { JourneyViewModel(repository: journeys) }
    func makeNaturalJourneyViewModel() -> NaturalJourneyViewModel { NaturalJourneyViewModel(repository: naturalJourneys) }
    func makeChatViewModel() -> ChatViewModel { ChatViewModel(repository: chat) }
    func makeLocationViewModel() -> LocationViewModel { LocationViewModel(adapter: location()) }
}
