import Foundation

@MainActor
struct RootDependencies {
    let onboarding: OnboardingModel
    let networkMap: NetworkViewModel
    let mapPresentation: MapPresentationModel
    let account: AccountModel
    let makeDeparturesViewModel: (StationID) -> DeparturesViewModel
    let nearbyStations: NearbyStationsViewModel
    let makeSavedPlacePicker: () -> SavedPlacePickerViewModel
}

@MainActor
struct AppDependencies {
    let authSession: AuthSessionViewModel
    let onboarding: OnboardingModel
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
        let onboarding = OnboardingModel()
        let departures = LiveDeparturesRepository(transport: transport)
        let search = LiveSearchRepository(transport: transport)
        let network = LiveNetworkRepository(transport: transport)
        let makeDeparturesViewModel: @MainActor (StationID) -> DeparturesViewModel = { stationID in
            DeparturesViewModel(stationID: stationID, repository: departures)
        }
        let baseJourneys = LiveJourneyRepository(transport: transport)
        let journeys = PreferenceAwareJourneyRepository(
            base: baseJourneys,
            account: account
        )
        let naturalIntentParser = FoundationModelsIntentParser()
        let onDeviceNaturalJourneys = OnDeviceNaturalJourneyService(
            parser: naturalIntentParser,
            places: OnDevicePlaceResolver { query, coordinate in
                try await search.search(query: query, near: coordinate)
            },
            journeys: baseJourneys
        )
        let naturalJourneys = HybridNaturalJourneyRepository(
            parser: naturalIntentParser,
            onDevice: onDeviceNaturalJourneys,
            remote: LiveNaturalJourneyRepository(transport: transport)
        )
        return AppDependencies(
            authSession: AuthSessionViewModel(
                client: BetterAuthClient(baseURL: configuration.apiBaseURL),
                vault: vault,
                account: account,
                unauthorizedEvents: unauthorized.stream
            ),
            onboarding: onboarding,
            root: RootDependencies(
                onboarding: onboarding,
                networkMap: NetworkViewModel(repository: network),
                mapPresentation: MapPresentationModel(
                    searchRepository: search,
                    journeyRepository: journeys,
                    naturalJourneyRepository: naturalJourneys,
                    account: account,
                    locationAdapter: CoreLocationAdapter()
                ),
                account: account,
                makeDeparturesViewModel: makeDeparturesViewModel,
                nearbyStations: NearbyStationsViewModel(
                    network: network,
                    makeDeparturesViewModel: makeDeparturesViewModel
                ),
                makeSavedPlacePicker: {
                    SavedPlacePickerViewModel(repository: search)
                }
            )
        )
    }
}

/// Builds only the in-memory dependencies requested by an individual preview.
/// Lazy properties keep a small view from initializing unrelated feature graphs.
@MainActor
final class PreviewDependencies {
    private let session = StoredAuthSession(
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

    lazy var account = AccountModel(
        store: AccountLocalStore(
            defaults: UserDefaults(suiteName: "dev.via.preview")!
        ),
        remote: InMemoryAccountRemote(),
        synchronizationEnabled: false
    )

    lazy var onboarding = OnboardingModel(
        store: OnboardingStore(
            defaults: UserDefaults(suiteName: "dev.via.preview.onboarding")!
        )
    )

    lazy var authSession = AuthSessionViewModel(
        client: InMemoryAuthenticationClient(session: session),
        vault: InMemoryAuthSessionVault(session: session),
        account: account
    )

    lazy var mapPresentation = MapPresentationModel(
        searchRepository: InMemorySearchRepository(response: .mapPreview),
        journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
        naturalJourneyRepository: InMemoryNaturalJourneyRepository(
            result: .unsupported(
                message: "Décris simplement le trajet que tu veux faire.",
                examples: ["Je veux arriver à Bastille avant 19 h"]
            )
        ),
        account: account,
        locationAdapter: InMemoryLocationAdapter()
    )

    lazy var nearbyStations = NearbyStationsViewModel(
        network: InMemoryNetworkRepository.mapPreview,
        makeDeparturesViewModel: { [self] stationID in
            makeDeparturesViewModel(for: stationID)
        }
    )

    func makeDeparturesViewModel(for stationID: StationID) -> DeparturesViewModel {
        DeparturesViewModel(
            stationID: stationID,
            repository: InMemoryDeparturesRepository()
        )
    }

    func makeSavedPlacePicker() -> SavedPlacePickerViewModel {
        SavedPlacePickerViewModel(
            repository: InMemorySearchRepository(response: .mapPreview)
        )
    }
}
