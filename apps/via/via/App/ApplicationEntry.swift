import SwiftUI

@main
@MainActor
struct ApplicationEntry: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isShowingLaunchAnimation = true
    @State private var isContinuingAsGuest = false
    @State private var networkViewModel: NetworkViewModel
    @State private var stationsViewModel: StationsViewModel
    @State private var linesViewModel: LinesViewModel
    @State private var selectedStationModel: SelectedStationModel
    @State private var searchViewModel: SearchViewModel
    @State private var activeJourneyModel: ActiveJourneyModel
    @State private var reportViewModel: ReportViewModel
    @State private var authSessionViewModel: AuthSessionViewModel
    @State private var onboardingModel: OnboardingModel
    @State private var onboardingProfileModel: OnboardingProfileModel
    @State private var locationModel: LocationModel
    @State private var accountModel: AccountModel
    @State private var favoriteRoutesModel: FavoriteRoutesModel
    @State private var profileModel: ProfileModel
    @State private var pushNotificationManager: PushNotificationManager
    @State private var journeyNotificationCoordinator: JourneyNotificationCoordinator
    @State private var notificationInboxRemote: any NotificationInboxRemote
    private let journeyDepartureChoicesRepository: any JourneyDepartureChoicesRepository

    init() {
        let pushNotificationManager = PushNotificationManager.shared
        let dependencies = Self.makeDependencies(pushNotificationManager: pushNotificationManager)
        journeyDepartureChoicesRepository = dependencies.journeyDepartureChoicesRepository
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
                reportRepository: dependencies.reportRepository,
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
            journeyNotificationManager: dependencies.journeyNotificationCoordinator,
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
        _onboardingProfileModel = State(
            initialValue: dependencies.onboardingProfileModel,
        )
        _locationModel = State(initialValue: dependencies.locationModel)
        _accountModel = State(initialValue: dependencies.accountModel)
        _favoriteRoutesModel = State(
            initialValue: FavoriteRoutesModel(
                networkRepository: dependencies.networkRepository,
            ),
        )
        _profileModel = State(initialValue: ProfileModel())
        _pushNotificationManager = State(initialValue: dependencies.pushNotificationManager)
        _journeyNotificationCoordinator = State(initialValue: dependencies.journeyNotificationCoordinator)
        _notificationInboxRemote = State(initialValue: dependencies.notificationInboxRemote)
    }

    var body: some Scene {
        WindowGroup {
            applicationRoot
            .task(id: onboardingModel.isCompleted) {
                guard onboardingModel.isCompleted else { return }
                await preloadInitialData()
            }
            .task {
                await authSessionViewModel.restore()
                await journeyNotificationCoordinator.restore()
                await pushNotificationManager.setNotificationsAuthorized(
                    journeyNotificationCoordinator.isAuthorized
                )
                await pushNotificationManager.flush()
            }
            .task {
                await activeJourneyModel.restore()
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await authSessionViewModel.sceneBecameActive()
                await activeJourneyModel.sceneBecameActive()
                await journeyNotificationCoordinator.sceneBecameActive()
                await pushNotificationManager.setNotificationsAuthorized(
                    journeyNotificationCoordinator.isAuthorized
                )
                await pushNotificationManager.flush()
            }
            .task(id: authSessionViewModel.session?.user.id) {
                if authSessionViewModel.session != nil {
                    await pushNotificationManager.registerForAuthenticatedSession()
                } else {
                    await pushNotificationManager.setAuthenticated(false)
                }
                await pushNotificationManager.flush()
            }
            .task(id: journeyNotificationCoordinator.authorizationStatus.rawValue) {
                await pushNotificationManager.setNotificationsAuthorized(
                    journeyNotificationCoordinator.isAuthorized
                )
            }
        }
    }

    /// Starts the first screen's network work while the in-app launch
    /// animation is still covering the shell. The individual views keep
    /// their own task for refresh loops, but their initial request is already
    /// in flight by the time they become visible.
    private func preloadInitialData() async {
        stationsViewModel.loadIfNeeded()

        async let lines: Void = linesViewModel.loadIfNeeded()
        async let network: Void = networkViewModel.preload()

        await lines
        await network
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
            } else if !onboardingModel.isSetupCompleted {
                if authSessionViewModel.isSignedIn || isContinuingAsGuest {
                    OnboardingProfileView(
                        model: onboardingProfileModel,
                        onBack: stepBackFromProfile,
                        onComplete: onboardingModel.completeSetup
                    )
                    .transition(.opacity)
                } else {
                    OnboardingAccountView(
                        authSessionViewModel: authSessionViewModel,
                        onBack: stepBackToPresentation,
                        onContinueAsGuest: { isContinuingAsGuest = true }
                    )
                    .transition(.opacity)
                }
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
                    pushNotificationManager: pushNotificationManager,
                    journeyNotificationCoordinator: journeyNotificationCoordinator,
                    journeyDepartureChoicesRepository: journeyDepartureChoicesRepository,
                    onReplayOnboarding: replayOnboarding,
                    notificationInboxRemote: notificationInboxRemote,
                )
                .transition(.opacity)
            }
        }
    }

    /// The first question hands the traveller back to the screen they came
    /// from: the account step for a guest, the presentation for someone who
    /// arrived already signed in — signing out to see a login screen again is
    /// not what a back tap means. Answers already given are kept either way.
    private func stepBackFromProfile() {
        guard !authSessionViewModel.isSignedIn, isContinuingAsGuest else {
            stepBackToPresentation()
            return
        }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            isContinuingAsGuest = false
        }
    }

    private func stepBackToPresentation() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            isContinuingAsGuest = false
            onboardingModel.stepBackToPresentation()
        }
    }

    /// Réglages hands the first run back: the carousel, the account step and
    /// the profile questions replay in order. Nothing stored is thrown away —
    /// the questions reopen on the answers already given, so leaving halfway
    /// costs the traveller nothing.
    private func replayOnboarding() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            isContinuingAsGuest = false
            onboardingModel.reset()
        }
    }

    private static func makeDependencies(
        pushNotificationManager: PushNotificationManager
    ) -> Dependencies {
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
                journeyDepartureChoicesRepository: InMemoryJourneyDepartureChoicesRepository.unavailable,
                naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
                naturalLanguageAvailability: { .available },
                naturalJourneyMetrics: NoOpNaturalJourneyMetrics(),
                lineStatusRepository: PreviewLineStatusRepository(),
                accountModel: accountModel,
                authSessionViewModel: AuthSessionViewModel(
                    client: InMemoryAuthenticationClient(session: previewSession),
                    vault: InMemoryAuthSessionVault(),
                    account: accountModel,
                    onAuthenticatedSessionEnded: {
                        await pushNotificationManager.unregisterCurrentInstallation()
                        await pushNotificationManager.setAuthenticated(false)
                    },
                ),
                onboardingModel: OnboardingModel(),
                onboardingProfileModel: OnboardingProfileModel(),
                pushNotificationManager: pushNotificationManager,
                journeyNotificationCoordinator: JourneyNotificationCoordinator(
                    activeJourneyManager: pushNotificationManager
                ),
                notificationInboxRemote: NoOpNotificationInboxRemote(),
            )
        }

        // Product endpoints remain usable anonymously; 401 events still invalidate a cached session.
        let authSessionVault = KeychainAuthSessionVault(apiBaseURL: configuration.apiBaseURL)
        let (unauthorizedEvents, unauthorizedContinuation) = AsyncStream<String>.makeStream()
        let transport = APITransport(
            baseURL: configuration.apiBaseURL,
            authSessionVault: authSessionVault,
            onUnauthorized: { rejectedBearerToken in
                unauthorizedContinuation.yield(rejectedBearerToken)
            },
        )
        pushNotificationManager.configure(
            configuration: configuration,
            remote: LivePushNotificationRemote(transport: transport)
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
            reportRepository: LiveReportRepository(transport: transport),
            activeJourneyStore: UserDefaultsActiveJourneyStore(),
            activityManager: JourneyActivityManager(),
            connectivityMonitor: NetworkConnectivityMonitor(),
            journeyRepository: journeyRepository,
            journeyDepartureChoicesRepository: LiveJourneyDepartureChoicesRepository(
                transport: transport
            ),
            naturalJourneyRepository: naturalJourneyRepository,
            naturalLanguageAvailability: { naturalIntentParser.availability },
            naturalJourneyMetrics: naturalJourneyMetrics,
            lineStatusRepository: LiveLineStatusRepository(transport: transport),
            accountModel: accountModel,
            authSessionViewModel: AuthSessionViewModel(
                client: BetterAuthClient(baseURL: configuration.apiBaseURL),
                vault: authSessionVault,
                account: accountModel,
                unauthorizedEvents: unauthorizedEvents,
                onAuthenticatedSessionEnded: {
                    await pushNotificationManager.unregisterCurrentInstallation()
                    await pushNotificationManager.setAuthenticated(false)
                },
            ),
            onboardingModel: OnboardingModel(),
            onboardingProfileModel: OnboardingProfileModel(),
            pushNotificationManager: pushNotificationManager,
            journeyNotificationCoordinator: JourneyNotificationCoordinator(
                activeJourneyManager: pushNotificationManager
            ),
            notificationInboxRemote: LiveNotificationInboxRemote(transport: transport),
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
        let journeyDepartureChoicesRepository: any JourneyDepartureChoicesRepository
        let naturalJourneyRepository: any NaturalJourneyRepository
        let naturalLanguageAvailability: @Sendable () -> NaturalLanguageAvailability
        let naturalJourneyMetrics: any NaturalJourneyMetricsRecording
        let lineStatusRepository: any LineStatusRepository
        let accountModel: AccountModel
        let authSessionViewModel: AuthSessionViewModel
        let onboardingModel: OnboardingModel
        let onboardingProfileModel: OnboardingProfileModel
        let pushNotificationManager: PushNotificationManager
        let journeyNotificationCoordinator: JourneyNotificationCoordinator
        let notificationInboxRemote: any NotificationInboxRemote
    }
}
