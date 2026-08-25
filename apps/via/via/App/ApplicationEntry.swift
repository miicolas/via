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
    @State private var nearbyStationsModel: NearbyStationsModel
    @State private var linesViewModel: LinesViewModel
    @State private var selectedStationModel: SelectedStationModel
    @State private var searchViewModel: SearchViewModel
    @State private var activeJourneyModel: ActiveJourneyModel
    @State private var plannedJourneyDraftModel: PlannedJourneyDraftModel
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
        let dependencies = ApplicationDependencyFactory.make(
            pushNotificationManager: pushNotificationManager
        )
        journeyDepartureChoicesRepository = dependencies.journeyDepartureChoicesRepository
        // One filter and one nearby set for the whole shell: the map's
        // annotations and the Stations list are two views of it, and the
        // filter outlives the launch that set it.
        let stationMapFilterStore = StationMapFilterStore(
            persistence: UserDefaultsStationMapFilterPersistence(),
        )
        let nearbyStationsModel = NearbyStationsModel(
            repository: dependencies.networkRepository,
            filterStore: stationMapFilterStore,
        )
        _nearbyStationsModel = State(initialValue: nearbyStationsModel)
        _networkViewModel = State(
            initialValue: NetworkViewModel(
                repository: dependencies.networkRepository,
                filterStore: stationMapFilterStore,
                nearby: nearbyStationsModel,
            ),
        )
        _stationsViewModel = State(
            initialValue: StationsViewModel(
                locationModel: dependencies.locationModel,
                networkRepository: dependencies.networkRepository,
                departuresRepository: dependencies.departuresRepository,
                nearby: nearbyStationsModel,
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
        _plannedJourneyDraftModel = State(
            initialValue: PlannedJourneyDraftModel(store: dependencies.plannedJourneyDraftStore)
        )
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
                await ApplicationLifecycle.restore(
                    authSessionViewModel: authSessionViewModel,
                    journeyNotificationCoordinator: journeyNotificationCoordinator,
                    activeJourneyModel: activeJourneyModel,
                    plannedJourneyDraftModel: plannedJourneyDraftModel,
                    pushNotificationManager: pushNotificationManager
                )
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
                    nearbyStationsModel: nearbyStationsModel,
                    linesViewModel: linesViewModel,
                    selectedStationModel: selectedStationModel,
                    searchViewModel: searchViewModel,
                    activeJourneyModel: activeJourneyModel,
                    plannedJourneyDraftModel: plannedJourneyDraftModel,
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

}
