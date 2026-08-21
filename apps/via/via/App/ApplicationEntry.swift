import SwiftUI

@main
@MainActor
struct ApplicationEntry: App {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isShowingLaunchAnimation = true
    @State private var networkViewModel: NetworkViewModel
    @State private var stationsViewModel: StationsViewModel
    @State private var linesViewModel: LinesViewModel
    @State private var selectedStationModel: SelectedStationModel
    @State private var searchViewModel: SearchViewModel
    @State private var activeJourneyModel: ActiveJourneyModel
    @State private var reportViewModel: ReportViewModel
    @State private var authSessionViewModel: AuthSessionViewModel
    @State private var onboardingModel: OnboardingModel
    @State private var locationModel: LocationModel
    @State private var accountModel: AccountModel
    @State private var favoriteRoutesModel: FavoriteRoutesModel
    @State private var profileModel: ProfileModel

    init() {
        let dependencies = Self.makeDependencies()
        _networkViewModel = State(
            initialValue: NetworkViewModel(repository: dependencies.networkRepository),
        )
        _stationsViewModel = State(
            initialValue: StationsViewModel(
                locationModel: dependencies.locationModel,
                networkRepository: dependencies.networkRepository,
                departuresRepository: dependencies.departuresRepository,
            ),
        )
        _linesViewModel = State(
            initialValue: LinesViewModel(repository: dependencies.lineStatusRepository),
        )
        _selectedStationModel = State(
            initialValue: SelectedStationModel(
                departuresRepository: dependencies.departuresRepository,
                account: dependencies.accountModel,
                locationModel: dependencies.locationModel,
            ),
        )
        _searchViewModel = State(
            initialValue: SearchViewModel(
                repository: dependencies.searchRepository,
                journeyRepository: dependencies.journeyRepository,
                locationModel: dependencies.locationModel,
                account: dependencies.accountModel,
                naturalJourneyRepository: dependencies.naturalJourneyRepository,
                naturalLanguageAvailability: dependencies.naturalLanguageAvailability,
                naturalJourneyMetrics: dependencies.naturalJourneyMetrics,
            ),
        )
        let activeJourneyModel = ActiveJourneyModel(
            locationModel: dependencies.locationModel,
            journeyRepository: dependencies.journeyRepository,
            store: dependencies.activeJourneyStore,
            activityManager: dependencies.activityManager,
            connectivity: dependencies.connectivityMonitor,
        )
        _activeJourneyModel = State(initialValue: activeJourneyModel)
        _reportViewModel = State(
            initialValue: ReportViewModel(
                contextResolver: ReportContextResolver(
                    locationModel: dependencies.locationModel,
                    networkRepository: dependencies.networkRepository,
                ),
                repository: dependencies.reportRepository,
                searchRepository: dependencies.searchRepository,
                activeJourneyProvider: activeJourneyModel,
            ),
        )
        _authSessionViewModel = State(
            initialValue: dependencies.authSessionViewModel,
        )
        _onboardingModel = State(
            initialValue: dependencies.onboardingModel,
        )
        _locationModel = State(initialValue: dependencies.locationModel)
        _accountModel = State(initialValue: dependencies.accountModel)
        _favoriteRoutesModel = State(
            initialValue: FavoriteRoutesModel(
                networkRepository: dependencies.networkRepository,
            ),
        )
        _profileModel = State(initialValue: ProfileModel())
    }

    var body: some Scene {
        WindowGroup {
            applicationRoot
            .task {
                await authSessionViewModel.restore()
            }
            .task {
                await activeJourneyModel.restore()
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await authSessionViewModel.sceneBecameActive()
                await activeJourneyModel.sceneBecameActive()
            }
        }
    }

    private var applicationRoot: some View {
        ZStack {
            if isShowingLaunchAnimation {
                LaunchAnimationView {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        isShowingLaunchAnimation = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            } else if !onboardingModel.isCompleted {
                OnboardingView(onComplete: onboardingModel.complete)
                    .transition(.opacity)
            } else {
                MapShellView(
                    networkViewModel: networkViewModel,
                    stationsViewModel: stationsViewModel,
                    linesViewModel: linesViewModel,
                    selectedStationModel: selectedStationModel,
                    searchViewModel: searchViewModel,
                    activeJourneyModel: activeJourneyModel,
                    reportViewModel: reportViewModel,
                    locationModel: locationModel,
                    accountModel: accountModel,
                    favoriteRoutesModel: favoriteRoutesModel,
                    authSessionViewModel: authSessionViewModel,
                    profileModel: profileModel,
                )
                .transition(.opacity)
            }
        }
    }

    private static func makeDependencies() -> Dependencies {
        guard let configuration = try? AppConfiguration.bundled() else {
            let accountModel = AccountModel(
                remote: InMemoryAccountRemote(),
                synchronizationEnabled: false,
            )
            accountModel.activateAnonymous()
            let previewSession = StoredAuthSession(
                bearerToken: "preview.token",
                user: AuthUser(
                    id: "preview",
                    appleUserIdentifier: "preview",
                    name: "Preview",
                    email: "preview@example.com",
                ),
                expiresAt: .distantFuture,
                lastValidatedAt: .now,
            )

            return Dependencies(
                locationModel: LocationModel(
                    adapter: InMemoryLocationAdapter(
                        coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470),
                    ),
                ),
                networkRepository: InMemoryNetworkRepository.mapPreview,
                departuresRepository: InMemoryDeparturesRepository.stationsPreview,
                searchRepository: InMemorySearchRepository.preview,
                reportRepository: InMemoryReportRepository(),
                activeJourneyStore: InMemoryActiveJourneyStore(),
                activityManager: NoOpJourneyActivityManager(),
                connectivityMonitor: InMemoryConnectivityMonitor(),
                journeyRepository: PreferenceAwareJourneyRepository(
                    base: InMemoryJourneyRepository(result: .mapPreview),
                    account: accountModel,
                ),
                naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
                naturalLanguageAvailability: { .available },
                naturalJourneyMetrics: NoOpNaturalJourneyMetrics(),
                lineStatusRepository: PreviewLineStatusRepository(),
                accountModel: accountModel,
                authSessionViewModel: AuthSessionViewModel(
                    client: InMemoryAuthenticationClient(session: previewSession),
                    vault: InMemoryAuthSessionVault(),
                    account: accountModel,
                ),
                onboardingModel: OnboardingModel(),
            )
        }

        // The network endpoints are public; unauthorized responses keep the default no-op handler.
        let authSessionVault = KeychainAuthSessionVault(apiBaseURL: configuration.apiBaseURL)
        let transport = APITransport(
            baseURL: configuration.apiBaseURL,
            authSessionVault: authSessionVault,
        )
        let accountModel = AccountModel(remote: LiveAccountRemote(transport: transport))
        accountModel.activateAnonymous()
        let journeyRepository = PreferenceAwareJourneyRepository(
            base: LiveJourneyRepository(transport: transport),
            account: accountModel,
        )
        let searchRepository = LiveSearchRepository(transport: transport)
        let naturalIntentParser = FoundationModelsIntentParser()
        let naturalJourneyMetrics = AppLogNaturalJourneyMetrics()
        let naturalJourneyRepository = OnDeviceNaturalJourneyService(
            parser: naturalIntentParser,
            places: OnDevicePlaceResolver { query, coordinate in
                return try await searchRepository.search(
                    query: query,
                    near: coordinate
                )
            },
            journeys: journeyRepository,
            metrics: naturalJourneyMetrics,
            requiresAccessibleStations: {
                UserDefaultsSearchFilterStore().load().requiresAccessibleStations
            },
        )

        return Dependencies(
            locationModel: LocationModel(adapter: CoreLocationAdapter()),
            networkRepository: LiveNetworkRepository(transport: transport),
            departuresRepository: LiveDeparturesRepository(transport: transport),
            searchRepository: searchRepository,
            reportRepository: InMemoryReportRepository(),
            activeJourneyStore: UserDefaultsActiveJourneyStore(),
            activityManager: JourneyActivityManager(),
            connectivityMonitor: NetworkConnectivityMonitor(),
            journeyRepository: journeyRepository,
            naturalJourneyRepository: naturalJourneyRepository,
            naturalLanguageAvailability: { naturalIntentParser.availability },
            naturalJourneyMetrics: naturalJourneyMetrics,
            lineStatusRepository: LiveLineStatusRepository(transport: transport),
            accountModel: accountModel,
            authSessionViewModel: AuthSessionViewModel(
                client: BetterAuthClient(baseURL: configuration.apiBaseURL),
                vault: authSessionVault,
                account: accountModel,
            ),
            onboardingModel: OnboardingModel(),
        )
    }

    private struct Dependencies {
        let locationModel: LocationModel
        let networkRepository: any NetworkRepository
        let departuresRepository: any DeparturesRepository
        let searchRepository: any SearchRepository
        let reportRepository: any ReportRepository
        let activeJourneyStore: any ActiveJourneyStore
        let activityManager: any JourneyActivityManaging
        let connectivityMonitor: any ConnectivityMonitoring
        let journeyRepository: any JourneyRepository
        let naturalJourneyRepository: any NaturalJourneyRepository
        let naturalLanguageAvailability: @Sendable () -> NaturalLanguageAvailability
        let naturalJourneyMetrics: any NaturalJourneyMetricsRecording
        let lineStatusRepository: any LineStatusRepository
        let accountModel: AccountModel
        let authSessionViewModel: AuthSessionViewModel
        let onboardingModel: OnboardingModel
    }
}
