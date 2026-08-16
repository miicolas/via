import Foundation

@MainActor
struct AppDependencies {
    let network: any NetworkRepository
    let search: any SearchRepository
    let recentSearches: any RecentSearchRepository
    let departures: any DeparturesRepository
    let journeys: any JourneyRepository
    let naturalJourneys: any NaturalJourneyRepository
    let chat: any ChatRepository
    let location: () -> any LocationAdapter

    static func live(configuration: AppConfiguration) throws -> AppDependencies {
        let identity = KeychainClientIdentityRepository()
        let client = LiveViaAPIClient(baseURL: configuration.apiBaseURL, clientID: try identity.clientID())
        let search = LiveSearchRepository(client: client)
        let journeys = LiveJourneyRepository(client: client)
        return AppDependencies(
            network: LiveNetworkRepository(client: client),
            search: search,
            recentSearches: UserDefaultsRecentSearchRepository(),
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
        AppDependencies(
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
