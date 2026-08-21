import MapKit
import SwiftUI

extension MKCoordinateRegion {
    static let paris = MKCoordinateRegion(
        center: .init(latitude: 48.8566, longitude: 2.3522),
        latitudinalMeters: 4000,
        longitudinalMeters: 4000
    )
}
/// Root screen: full-screen map with a persistent bottom sheet hosting the
/// Stations / Lignes / Signaler / Recherche tabs, Find My style.
struct MapShellView: View {
    let networkViewModel: NetworkViewModel
    let stationsViewModel: StationsViewModel
    let linesViewModel: LinesViewModel
    let selectedStationModel: SelectedStationModel
    let searchViewModel: SearchViewModel
    let activeJourneyModel: ActiveJourneyModel
    let reportViewModel: ReportViewModel
    let onboardingModel: OnboardingModel
    let locationModel: LocationModel
    let accountModel: AccountModel
    let favoriteRoutesModel: FavoriteRoutesModel
    let authSessionViewModel: AuthSessionViewModel
    let profileModel: ProfileModel

    @State private var showTabSheet: Bool = true
    @State private var activeTab: MapShellTab = .stations
    @State private var previousTab: MapShellTab = .stations
    @State private var position: MapCameraPosition = .region(.paris)
    @State private var selectedMapStation: StationMapItem?

    @State private var isLargeScreen: Bool = false
    // The reference opens with the map still visible above the content sheet.
    @State private var activeDetent: PresentationDetent = .fraction(0.45)
    @State private var detailSheetDetent: PresentationDetent = .height(80)
    @State private var accountSheetDestination: AccountSheetDestination?
    @State private var accountSheetDetent: PresentationDetent = .height(80)
    // IA research and the journey detail share one stacked sheet slot, so only
    // one is ever presented above the tab sheet at a time.
    @State private var searchSheetDestination: SearchSheetDestination?
    @State private var journeySheetDetent: PresentationDetent = .large
    @State private var isOnboardingPresented = false

    init(
        networkViewModel: NetworkViewModel,
        stationsViewModel: StationsViewModel,
        linesViewModel: LinesViewModel,
        selectedStationModel: SelectedStationModel,
        searchViewModel: SearchViewModel,
        activeJourneyModel: ActiveJourneyModel,
        reportViewModel: ReportViewModel,
        onboardingModel: OnboardingModel,
        locationModel: LocationModel,
        accountModel: AccountModel,
        favoriteRoutesModel: FavoriteRoutesModel,
        authSessionViewModel: AuthSessionViewModel,
        profileModel: ProfileModel
    ) {
        self.networkViewModel = networkViewModel
        self.stationsViewModel = stationsViewModel
        self.linesViewModel = linesViewModel
        self.selectedStationModel = selectedStationModel
        self.searchViewModel = searchViewModel
        self.activeJourneyModel = activeJourneyModel
        self.reportViewModel = reportViewModel
        self.onboardingModel = onboardingModel
        self.locationModel = locationModel
        self.accountModel = accountModel
        self.favoriteRoutesModel = favoriteRoutesModel
        self.authSessionViewModel = authSessionViewModel
        self.profileModel = profileModel
    }

    var body: some View {
        NetworkMapView(
            viewModel: networkViewModel,
            position: $position,
            stationSelectionEnabled: activeTab != .search && searchSheetDestination == nil,
            journeyPresentation: displayedJourneyPresentation,
            journeyProgress: activeJourneyModel.progress?.mapQuantized,
            highlightedJourneySegmentID: displayedHighlightedSectionID,
            selectedStation: $selectedMapStation
        )
            // Keeps the Apple legal attribution above the collapsed sheet.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(height: 65)
            }
            .sheet(isPresented: $showTabSheet) {
                sheetContent
                .adaptiveSheet(380, isActive: isLargeScreen)
                .sheet(isPresented: $isOnboardingPresented) {
                    OnboardingView(model: onboardingModel)
                }
            }
            .onChange(of: selectedMapStation) { _, newValue in
                guard let newValue else { return }
                // Clear right away so re-tapping the same annotation reopens the sheet.
                selectedMapStation = nil
                activeTab = .stations
                detailSheetDetent = isLargeScreen ? .fraction(0.97) : .large
                selectedStationModel.select(newValue)
            }
            .onChange(of: displayedJourneyPresentation) { _, presentation in
                guard let mapRect = presentation?.mapRect else { return }
                position = .rect(mapRect)
            }
            .onChange(of: displayedHighlightedSectionID) { _, sectionID in
                frameJourney(sectionID: sectionID)
            }
            .onChange(of: activeDetent) { _, detent in
                // Collapsing the sheet used to leave the running journey off
                // screen with nothing to bring it back.
                guard detent == collapsedDetent, activeJourneyModel.isActive else { return }
                frameJourney(sectionID: displayedHighlightedSectionID)
            }
            .onChange(of: activeJourneyModel.session?.journey.id) { _, journeyID in
                if journeyID != nil {
                    showActiveJourney()
                } else if activeJourneyModel.arrival == nil, isJourneySheetUp {
                    // The journey ended (cancelled or expired) with no arrival
                    // screen to show: close the sheet.
                    searchSheetDestination = nil
                }
            }
            .onChange(of: activeJourneyModel.arrival?.journeyID) { _, journeyID in
                if journeyID != nil {
                    showActiveJourney()
                } else if activeJourneyModel.session == nil, isJourneySheetUp {
                    // The arrival screen was dismissed: close the sheet.
                    searchSheetDestination = nil
                }
            }
            .onChange(of: searchViewModel.isNaturalSearchPresented) { _, presented in
                // Bridge the IA lifecycle to the shared sheet slot: every open
                // and dismiss path flows through the view model.
                if presented {
                    if searchSheetDestination == nil { searchSheetDestination = .naturalSearch }
                } else if searchSheetDestination == .naturalSearch {
                    searchSheetDestination = nil
                }
            }
            .onChange(of: searchViewModel.naturalResultJourneyID) { _, journeyID in
                guard let journeyID else { return }
                // The IA sheet closes and the journey detail opens on the result.
                activeTab = .search
                journeySheetDetent = expandedDetent
                searchSheetDestination = .journey(journeyID)
                searchViewModel.consumeNaturalResultJourney()
            }
            .onChange(of: activeJourneyModel.isActive) { _, isActive in
                // Once guidance is running, peek so the map behind stays visible.
                if isActive { journeySheetDetent = .height(80) }
            }
            .onChange(of: searchSheetDestination) { _, destination in
                // Reset the detent so the next journey opens expanded, not on the peek.
                if destination == nil { journeySheetDetent = expandedDetent }
            }
            .onChange(of: activeTab) { oldValue, newValue in
                if newValue == .search, oldValue != .search {
                    // Signaler is reached *from* search (the guidance panel's
                    // report button) and search comes back on its own for the
                    // running journey, so remembering it sent closing search
                    // straight back into the report form.
                    if oldValue != .report {
                        previousTab = oldValue
                    }
                    activeDetent = hasJourneySurface ? guidanceDetent : expandedDetent
                } else if newValue == .report, oldValue != .report {
                    activeDetent = isLargeScreen ? .fraction(0.97) : .large
                } else if oldValue == .search, newValue != .search {
                    activeDetent = isLargeScreen ? .fraction(0.97) : .fraction(0.45)
                } else if oldValue == .report, newValue != .report {
                    activeDetent = isLargeScreen ? .fraction(0.97) : .fraction(0.45)
                }
            }
            .onGeometryChange(for: Bool.self) {
                $0.size.width > 600
            } action: { newValue in
                // Remap detents before the size class flips so the sheet lands on a valid one.
                if newValue && activeDetent != collapsedDetent {
                    activeDetent = .fraction(0.97)
                } else if !newValue && activeDetent == .fraction(0.97) {
                    activeDetent = .fraction(0.45)
                }

                if newValue && detailSheetDetent != .height(80) {
                    detailSheetDetent = .fraction(0.97)
                } else if !newValue && detailSheetDetent == .fraction(0.97) {
                    detailSheetDetent = .large
                }

                if newValue && journeySheetDetent != .height(80) {
                    journeySheetDetent = .fraction(0.97)
                } else if !newValue && journeySheetDetent == .fraction(0.97) {
                    journeySheetDetent = .large
                }

                isLargeScreen = newValue
            }
            .task {
                guard !onboardingModel.isCompleted else { return }
                isOnboardingPresented = true
            }
            .task(id: authSessionViewModel.session?.user.id) {
                if let user = authSessionViewModel.session?.user {
                    profileModel.activate(scope: .user(user.id), seedName: user.displayName)
                } else {
                    profileModel.activate(scope: .anonymous)
                }
            }
            .onOpenURL { url in
                guard url.scheme == "via", url.host == "journey" else { return }
                showActiveJourney()
                Task { await activeJourneyModel.restore() }
            }
    }

    private func closeSearch() {
        activeTab = previousTab
    }

    /// Only worth showing once the sheet is out of the way: with the sheet open,
    /// the guidance header says the same thing and the two overlap.
    private var isActiveJourneyCompactVisible: Bool {
        activeJourneyModel.isActive && activeDetent == collapsedDetent
    }

    @ViewBuilder
    private var activeJourneyCompact: some View {
        if let journey = activeJourneyModel.journey,
           let progress = activeJourneyModel.progress,
           let headline = activeJourneyModel.guidanceHeadline {
            ActiveJourneyCompactView(
                journey: journey,
                headline: headline,
                progress: progress,
                action: showActiveJourney
            )
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        SheetTabView(
            selection: $activeTab,
            activeDetent: $activeDetent,
            isLargeScreen: isLargeScreen,
            isAnotherSheetPresenting: selectedStationModel.overview != nil ||
                reportViewModel.isPresentingAnotherSheet ||
                accountSheetDestination != nil ||
                searchSheetDestination != nil,
            reservesCompactSpace: activeJourneyModel.isActive,
            isCompactVisible: isActiveJourneyCompactVisible,
            compactContent: { activeJourneyCompact }
        ) {
            Tab(value: .stations) {
                StationsView(
                    viewModel: stationsViewModel,
                    selectedStation: selectedStationModel,
                    isLargeScreen: $isLargeScreen,
                    detailDetent: $detailSheetDetent,
                    profileModel: profileModel,
                    onOpenSearch: { activeTab = .search },
                    naturalLanguageAccess: searchViewModel.naturalLanguageAccess,
                    showsNaturalSearchDiscovery: searchViewModel.showsNaturalSearchDiscovery,
                    onOpenNaturalSearch: {
                        searchViewModel.openNaturalSearch()
                        activeTab = .search
                    },
                    onOpenProfile: { presentAccountSheet(.profile) },
                    onOpenSettings: { presentAccountSheet(.settings) }
                )
                .sheetTabBarVisibility()
            } label: {
                MapShellTab.stations.tabLabel
            }

            Tab(value: .lines) {
                LinesView(viewModel: linesViewModel)
                    .sheetTabBarVisibility()
            } label: {
                MapShellTab.lines.tabLabel
            }

            Tab(value: .report) {
                ReportView(viewModel: reportViewModel)
                    .sheetTabBarVisibility()
            } label: {
                MapShellTab.report.tabLabel
            }

            Tab(value: MapShellTab.search, role: .search) {
                SearchView(
                    viewModel: searchViewModel,
                    activeJourneyModel: activeJourneyModel,
                    onClose: closeSearch,
                    onInspectJourney: { journey in
                        journeySheetDetent = expandedDetent
                        searchSheetDestination = .journey(journey.id)
                    },
                    onShowActiveJourney: showActiveJourney
                )
                .sheetTabBarVisibility()
            }
        }
        .sheet(item: $accountSheetDestination) { destination in
            switch destination {
            case .profile:
                // The editor sizes the sheet to its own form rather than
                // opening on the collapsible detents the station detail uses.
                ProfileEditorView(model: profileModel)
            case .settings:
                SettingsView(
                    accountModel: accountModel,
                    favoriteRoutesModel: favoriteRoutesModel,
                    searchViewModel: searchViewModel,
                    authSessionViewModel: authSessionViewModel,
                    profileModel: profileModel,
                    locationModel: locationModel
                )
                .detailSheetPresentation(
                    isLargeScreen: isLargeScreen,
                    selection: $accountSheetDetent
                )
            }
        }
        .sheet(item: $searchSheetDestination) { destination in
            switch destination {
            case .naturalSearch:
                NaturalJourneySheet(viewModel: searchViewModel)
            case let .journey(journeyID):
                JourneySheetView(
                    journeyID: journeyID,
                    searchViewModel: searchViewModel,
                    activeJourneyModel: activeJourneyModel,
                    isLargeScreen: isLargeScreen,
                    detent: $journeySheetDetent,
                    onExpandMap: { journeySheetDetent = .height(80) },
                    onOpenReport: {
                        searchSheetDestination = nil
                        activeTab = .report
                    }
                )
            }
        }
    }

    private var isJourneySheetUp: Bool {
        if case .journey = searchSheetDestination { return true }
        return false
    }

    private var displayedJourneyPresentation: JourneyMapPresentation? {
        activeJourneyModel.mapPresentation
            ?? ((activeTab == .search || isJourneySheetUp) ? searchViewModel.mapPresentation : nil)
    }

    private var displayedHighlightedSectionID: String? {
        activeJourneyModel.highlightedSectionID
            ?? ((activeTab == .search || isJourneySheetUp) ? searchViewModel.highlightedJourneySectionID : nil)
    }

    private func presentAccountSheet(_ destination: AccountSheetDestination) {
        accountSheetDetent = isLargeScreen ? .fraction(0.97) : .large
        accountSheetDestination = destination
    }

    /// Frames the part of the journey that is still ahead when guidance is
    /// running, and the current section otherwise.
    private func frameJourney(sectionID: String?) {
        guard let presentation = displayedJourneyPresentation else { return }
        let mapRect = activeJourneyModel.isActive
            ? presentation.mapRect(remainingFrom: activeJourneyModel.progress)
            : presentation.mapRect(for: sectionID)
        guard let mapRect else { return }
        position = .rect(mapRect)
    }

    private func showActiveJourney() {
        activeTab = .search
        if let journeyID = activeJourneyModel.journey?.id ?? activeJourneyModel.arrival?.journeyID {
            searchSheetDestination = .journey(journeyID)
        }
    }

    private var hasJourneySurface: Bool {
        activeJourneyModel.isActive || activeJourneyModel.arrival != nil
    }

    private var collapsedDetent: PresentationDetent {
        SheetTabDetents.collapsed(hasCompactContent: activeJourneyModel.isActive)
    }

    private var guidanceDetent: PresentationDetent {
        isLargeScreen ? .fraction(0.97) : .fraction(0.45)
    }

    private var expandedDetent: PresentationDetent {
        isLargeScreen ? .fraction(0.97) : .large
    }
}

#Preview {
    let locationModel = LocationModel(
        adapter: InMemoryLocationAdapter(
            coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470)
        )
    )
    let accountModel: AccountModel = {
        let model = AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        model.activateAnonymous()
        return model
    }()
    let departures = InMemoryDeparturesRepository.stationsPreview

    MapShellView(
        networkViewModel: NetworkViewModel(repository: InMemoryNetworkRepository.mapPreview),
        stationsViewModel: StationsViewModel(
            locationModel: locationModel,
            networkRepository: InMemoryNetworkRepository.mapPreview,
            departuresRepository: departures
        ),
        linesViewModel: LinesViewModel(repository: PreviewLineStatusRepository()),
        selectedStationModel: SelectedStationModel(
            departuresRepository: departures,
            account: accountModel,
            locationModel: locationModel
        ),
        searchViewModel: SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
            locationModel: locationModel,
            account: accountModel
        ),
        activeJourneyModel: ActiveJourneyModel(
            locationModel: locationModel,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview)
        ),
        reportViewModel: ReportViewModel(
            contextResolver: ReportContextResolver(
                locationModel: locationModel,
                networkRepository: InMemoryNetworkRepository.mapPreview
            ),
            repository: InMemoryReportRepository(),
            searchRepository: InMemorySearchRepository.preview
        ),
        onboardingModel: OnboardingModel(store: OnboardingStore(defaults: .standard)),
        locationModel: locationModel,
        accountModel: accountModel,
        favoriteRoutesModel: FavoriteRoutesModel(
            networkRepository: InMemoryNetworkRepository.mapPreview
        ),
        authSessionViewModel: AuthSessionViewModel(
            client: InMemoryAuthenticationClient(session: StoredAuthSession(
                bearerToken: "preview.token",
                user: AuthUser(
                    id: "preview",
                    appleUserIdentifier: "preview",
                    name: "Alex Martin",
                    email: "alex@example.com"
                ),
                expiresAt: .distantFuture,
                lastValidatedAt: .now
            )),
            vault: InMemoryAuthSessionVault(),
            account: accountModel
        ),
        profileModel: ProfileModel(store: InMemoryProfileStore())
    )
}
