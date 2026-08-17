import Foundation

@MainActor
struct RootDependencies {
    let networkMap: NetworkViewModel
    let mapPresentation: MapPresentationModel
    let naturalJourney: NaturalJourneyViewModel
    let account: AccountModel
    let makeDeparturesViewModel: (StationID) -> DeparturesViewModel
}

@MainActor
struct AppDependencies {
    let authSession: AuthSessionViewModel
    let root: RootDependencies

    static func live(configuration: AppConfiguration) throws -> AppDependencies {
        let vault = KeychainAuthSessionVault(apiBaseURL: configuration.apiBaseURL)
        let unauthorized = AsyncStream.makeStream(of: Void.self)
        let transport = ViaTransport(
            baseURL: configuration.apiBaseURL,
            authSessionVault: vault,
            onUnauthorized: {
                unauthorized.continuation.yield(())
            }
        )
        let account = AccountModel(
            store: AccountLocalStore(),
            remote: LiveAccountRemote(transport: transport)
        )
        let departures = LiveDeparturesRepository(transport: transport)
        let search = LiveSearchRepository(transport: transport)
        let journeys = PreferenceAwareJourneyRepository(
            base: LiveJourneyRepository(transport: transport),
            account: account
        )
        let naturalJourneys = LiveNaturalJourneyRepository(transport: transport)
        return AppDependencies(
            authSession: AuthSessionViewModel(
                client: BetterAuthClient(baseURL: configuration.apiBaseURL),
                vault: vault,
                account: account,
                unauthorizedEvents: unauthorized.stream
            ),
            root: RootDependencies(
                networkMap: NetworkViewModel(
                    repository: LiveNetworkRepository(transport: transport)
                ),
                mapPresentation: MapPresentationModel(
                    searchRepository: search,
                    journeyRepository: journeys,
                    account: account,
                    locationAdapter: CoreLocationAdapter()
                ),
                naturalJourney: NaturalJourneyViewModel(repository: naturalJourneys),
                account: account,
                makeDeparturesViewModel: { stationID in
                    DeparturesViewModel(stationID: stationID, repository: departures)
                }
            )
        )
    }

    static var preview: AppDependencies {
        let session = StoredAuthSession(
            bearerToken: "preview-token",
            user: AuthUser(
                id: "preview-user",
                appleUserIdentifier: "preview-apple-user",
                name: "Camille Martin",
                email: "camille@example.com"
            ),
            expiresAt: .distantFuture,
            lastValidatedAt: .now
        )
        let vault = InMemoryAuthSessionVault(session: session)
        let account = AccountModel(
            store: AccountLocalStore(
                defaults: UserDefaults(suiteName: "dev.via.preview")!
            ),
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        let departures = InMemoryDeparturesRepository()
        let search = InMemorySearchRepository(response: .mapPreview)
        let journeys = InMemoryJourneyRepository(result: .mapPreview)
        let naturalJourneys = InMemoryNaturalJourneyRepository(
            result: .unsupported(
                message: "Décris simplement le trajet que tu veux faire.",
                examples: ["Je veux arriver à Bastille avant 19 h"]
            )
        )
        return AppDependencies(
            authSession: AuthSessionViewModel(
                client: InMemoryAuthenticationClient(session: session),
                vault: vault,
                account: account
            ),
            root: RootDependencies(
                networkMap: NetworkViewModel(
                    repository: InMemoryNetworkRepository.mapPreview
                ),
                mapPresentation: MapPresentationModel(
                    searchRepository: search,
                    journeyRepository: journeys,
                    account: account,
                    locationAdapter: InMemoryLocationAdapter()
                ),
                naturalJourney: NaturalJourneyViewModel(repository: naturalJourneys),
                account: account,
                makeDeparturesViewModel: { stationID in
                    DeparturesViewModel(stationID: stationID, repository: departures)
                }
            )
        )
    }
}
