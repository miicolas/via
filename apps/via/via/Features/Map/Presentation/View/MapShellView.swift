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
  let plannedJourneyDraftModel: PlannedJourneyDraftModel
  let reportViewModel: ReportViewModel
  let locationModel: LocationModel
  let accountModel: AccountModel
  let favoriteRoutesModel: FavoriteRoutesModel
  let authSessionViewModel: AuthSessionViewModel
  let profileModel: ProfileModel
  let pushNotificationManager: PushNotificationManager
  let journeyNotificationCoordinator: JourneyNotificationCoordinator
  let journeyDepartureChoicesRepository: any JourneyDepartureChoicesRepository
  /// Replays the first run from the root, offered inside Réglages.
  let onReplayOnboarding: @MainActor () -> Void
  let notificationInboxRemote: any NotificationInboxRemote

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
  // Journey details use one stacked sheet slot above the tab sheet.
  @State private var searchSheetDestination: SearchSheetDestination?
  @State private var journeySheetDetent: PresentationDetent = .large
  @State private var savedDestinationSelectionContext: SavedDestinationSelectionContext?
  @State private var savedDestinationDraft: SavedDestinationDraft?
  @State private var returnsToPreviousTabAfterSavingDestination = false

  init(
    networkViewModel: NetworkViewModel,
    stationsViewModel: StationsViewModel,
    linesViewModel: LinesViewModel,
    selectedStationModel: SelectedStationModel,
    searchViewModel: SearchViewModel,
    activeJourneyModel: ActiveJourneyModel,
    plannedJourneyDraftModel: PlannedJourneyDraftModel,
    reportViewModel: ReportViewModel,
    locationModel: LocationModel,
    accountModel: AccountModel,
    favoriteRoutesModel: FavoriteRoutesModel,
    authSessionViewModel: AuthSessionViewModel,
    profileModel: ProfileModel,
    pushNotificationManager: PushNotificationManager = .preview,
    journeyNotificationCoordinator: JourneyNotificationCoordinator = .preview,
    journeyDepartureChoicesRepository: any JourneyDepartureChoicesRepository =
      InMemoryJourneyDepartureChoicesRepository.unavailable,
    onReplayOnboarding: @escaping @MainActor () -> Void = {},
    notificationInboxRemote: any NotificationInboxRemote = NoOpNotificationInboxRemote()
  ) {
    self.networkViewModel = networkViewModel
    self.stationsViewModel = stationsViewModel
    self.linesViewModel = linesViewModel
    self.selectedStationModel = selectedStationModel
    self.searchViewModel = searchViewModel
    self.activeJourneyModel = activeJourneyModel
    self.plannedJourneyDraftModel = plannedJourneyDraftModel
    self.reportViewModel = reportViewModel
    self.locationModel = locationModel
    self.accountModel = accountModel
    self.favoriteRoutesModel = favoriteRoutesModel
    self.authSessionViewModel = authSessionViewModel
    self.profileModel = profileModel
    self.pushNotificationManager = pushNotificationManager
    self.journeyNotificationCoordinator = journeyNotificationCoordinator
    self.journeyDepartureChoicesRepository = journeyDepartureChoicesRepository
    self.onReplayOnboarding = onReplayOnboarding
    self.notificationInboxRemote = notificationInboxRemote
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
    .onChange(of: activeJourneyModel.session?.journey.id) { previousJourneyID, journeyID in
      if journeyID != nil {
        showActiveJourney()
      } else if previousJourneyID != nil {
        searchViewModel.resetSearch()
        if activeJourneyModel.arrival == nil, isJourneySheetUp {
          // The journey ended (cancelled or expired) with no arrival
          // screen to show: close the sheet.
          searchSheetDestination = nil
        }
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
    .onChange(of: searchViewModel.naturalResultJourneyID) { _, journeyID in
      guard let journeyID else { return }
      activeTab = .search
      journeySheetDetent = expandedDetent
      searchSheetDestination = .journey(journeyID)
      searchViewModel.consumeNaturalResultJourney()
    }
    .onChange(of: activeJourneyModel.isActive) { _, isActive in
      // Once guidance is running, peek so the map behind stays visible.
      if isActive { journeySheetDetent = journeyPeekDetent }
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
        activeDetent = activeJourneyModel.hasSurface ? guidanceDetent : expandedDetent
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

      if newValue && journeySheetDetent != journeyPeekDetent {
        journeySheetDetent = .fraction(0.97)
      } else if !newValue && journeySheetDetent == .fraction(0.97) {
        journeySheetDetent = .large
      }

      isLargeScreen = newValue
    }
    .task(id: authSessionViewModel.session?.user.id) {
      if let user = authSessionViewModel.session?.user {
        profileModel.activate(scope: .user(user.id), seedName: user.displayName)
      } else {
        profileModel.activate(scope: .anonymous)
      }
    }
    .task {
      routePendingNotificationIfNeeded()
    }
    .onChange(of: pushNotificationManager.pendingRoute) { _, _ in
      routePendingNotificationIfNeeded()
    }
    .onOpenURL { url in
      route(url)
    }
  }

  private func closeSearch() {
    savedDestinationSelectionContext = nil
    savedDestinationDraft = nil
    returnsToPreviousTabAfterSavingDestination = false
    searchViewModel.resetSearch()
    activeTab = previousTab
  }

  private func openJourney(_ result: SearchResult) {
    savedDestinationSelectionContext = nil
    activeTab = .search
    searchViewModel.selectDestination(result)
  }

  private func beginSavedDestinationSelection(
    _ context: SavedDestinationSelectionContext,
    preservingReturnDestination: Bool = false
  ) {
    if !preservingReturnDestination {
      returnsToPreviousTabAfterSavingDestination = activeTab != .search
    }
    savedDestinationSelectionContext = context
    savedDestinationDraft = nil
    searchViewModel.resetSearch()
    activeTab = .search
  }

  private func selectSavedDestinationResult(_ result: SearchResult) {
    guard let context = savedDestinationSelectionContext else { return }
    savedDestinationSelectionContext = nil

    if case .replacement(let draft) = context {
      let editedDestinationID = draft.existingDestination?.destinationID
      let editedPlaceID: String? = switch draft.target {
      case .place(_, let existing): existing?.id
      case .destination(_): nil
      }

      if let place = accountModel.savedPlace(for: result), place.id != editedPlaceID {
        presentPlaceEditor(place)
        return
      }
      if let destination = accountModel.savedDestination(for: result),
         destination.destinationID != editedDestinationID {
        presentDestinationEditor(destination)
        return
      }
      savedDestinationDraft = draft.replacingResult(result)
      return
    }

    if let place = accountModel.savedPlace(for: result) {
      presentPlaceEditor(place)
      return
    }
    if let destination = accountModel.savedDestination(for: result) {
      presentDestinationEditor(destination)
      return
    }

    switch context {
    case .place(let role):
      savedDestinationDraft = SavedDestinationDraft(
        target: .place(role, existing: nil),
        result: result,
        label: role.displayTitle,
        systemImage: role.systemImage
      )
    case .destination:
      savedDestinationDraft = SavedDestinationDraft(
        target: .destination(existing: nil),
        result: result,
        label: result.name,
        systemImage: SavedDestinationSymbols.suggestion(for: result)
      )
    case .replacement:
      break
    }
  }

  private func presentEditor(_ result: SearchResult) {
    returnsToPreviousTabAfterSavingDestination = false
    if let place = accountModel.savedPlace(for: result) {
      presentPlaceEditor(place)
    } else if let destination = accountModel.savedDestination(for: result) {
      presentDestinationEditor(destination)
    } else {
      savedDestinationDraft = SavedDestinationDraft(
        target: .destination(existing: nil),
        result: result,
        label: result.name,
        systemImage: SavedDestinationSymbols.suggestion(for: result)
      )
    }
  }

  private func presentPlaceEditor(_ place: SavedPlace) {
    savedDestinationDraft = SavedDestinationDraft(
      target: .place(place.role, existing: place),
      result: place.searchResult,
      label: place.role.displayTitle,
      systemImage: SavedDestinationSymbols.resolved(
        place.systemImage,
        fallback: place.role.systemImage
      )
    )
  }

  private func presentDestinationEditor(_ destination: SavedDestination) {
    savedDestinationDraft = SavedDestinationDraft(
      target: .destination(existing: destination),
      result: destination.searchResult,
      label: destination.label,
      systemImage: SavedDestinationSymbols.resolved(destination.systemImage)
    )
  }

  private func save(draft: SavedDestinationDraft, label: String, systemImage: String) {
    switch draft.target {
    case .place(let role, _):
      accountModel.setPlace(draft.result, role: role, systemImage: systemImage)
    case .destination(let existing):
      accountModel.saveDestination(
        draft.result,
        label: label,
        systemImage: systemImage,
        editing: existing
      )
    }

    if returnsToPreviousTabAfterSavingDestination {
      searchViewModel.resetSearch()
      activeTab = previousTab
    }
    returnsToPreviousTabAfterSavingDestination = false
  }

  private func deleteAction(for draft: SavedDestinationDraft) -> (() -> Void)? {
    switch draft.target {
    case .place(let role, let existing):
      guard existing != nil else { return nil }
      return { accountModel.removePlace(for: role) }
    case .destination(let existing):
      guard let existing else { return nil }
      return { accountModel.removeDestination(id: existing.id) }
    }
  }

  private func routePendingNotificationIfNeeded() {
    guard let url = pushNotificationManager.consumePendingRoute() else { return }
    route(url)
  }

  private func route(_ url: URL) {
    guard url.scheme == "via", let host = url.host else { return }
    if host == "notifications" {
      presentAccountSheet(.notifications)
      return
    }

    let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    if host == "line" {
      guard let routeID = queryItems.first(where: { $0.name == "routeId" })?.value else { return }
      activeTab = .lines
      linesViewModel.requestRoute(RouteID(rawValue: routeID))
      return
    }
    if host == "station" {
      guard let stationID = queryItems.first(where: { $0.name == "stationId" })?.value else {
        return
      }
      activeTab = .stations
      if let item = networkViewModel.stationMapItem(for: StationID(rawValue: stationID)) {
        selectedStationModel.select(item)
      }
      return
    }
    guard host == "journey" else { return }
    let pathComponents = url.pathComponents.filter { $0 != "/" }
    let journeyID =
      queryItems
      .first(where: { $0.name == "journeyId" })?.value
      .map(JourneyID.init(rawValue:))
      ?? pathComponents.first
      .map(JourneyID.init(rawValue:))
    let mode = queryItems.first(where: { $0.name == "mode" })?.value

    if mode == "reminder", let journeyID {
      Task { await routeScheduledJourney(journeyID) }
      return
    }
    guard mode == "active", let journeyID else { return }
    Task { await routeActiveJourney(journeyID) }
  }

  private func routeActiveJourney(_ journeyID: JourneyID) async {
    await activeJourneyModel.restore()
    guard activeJourneyModel.journey?.id == journeyID else { return }
    showActiveJourney()
  }

  private func routeScheduledJourney(_ journeyID: JourneyID) async {
    await journeyNotificationCoordinator.restore()
    guard journeyNotificationCoordinator.reminder(for: journeyID) != nil else { return }
    activeTab = .search
    journeySheetDetent = expandedDetent
    searchSheetDestination = .scheduledJourney(journeyID)
  }

  /// Only worth showing once the sheet is out of the way: with the sheet open,
  /// the guidance header says the same thing and the two overlap.
  private var isActiveJourneyCompactVisible: Bool {
    activeJourneyModel.isActive
      && !searchViewModel.isNaturalSearchPresented
      && activeDetent == collapsedDetent
  }

  @ViewBuilder
  private var journeyCompact: some View {
    if activeJourneyModel.isActive {
      ActiveJourneyCompactStrip(model: activeJourneyModel, action: showActiveJourney)
    }
  }

  @ViewBuilder
  private var sheetContent: some View {
    SheetTabView(
      selection: $activeTab,
      activeDetent: $activeDetent,
      isLargeScreen: isLargeScreen,
      isAnotherSheetPresenting: selectedStationModel.overview != nil
        || reportViewModel.isPresentingAnotherSheet || accountSheetDestination != nil
        || searchSheetDestination != nil || savedDestinationDraft != nil,
      hidesTabBar: searchViewModel.isNaturalSearchPresented,
      reservesCompactSpace: activeJourneyModel.isActive,
      isCompactVisible: isActiveJourneyCompactVisible,
      compactContent: { journeyCompact }
    ) {
      Tab(value: .stations) {
        StationsView(
          viewModel: stationsViewModel,
          selectedStation: selectedStationModel,
          accountModel: accountModel,
          isLargeScreen: $isLargeScreen,
          detailDetent: $detailSheetDetent,
          profileModel: profileModel,
          onOpenSearch: { activeTab = .search },
          naturalLanguageAccess: searchViewModel.naturalLanguageAccess,
          showsNaturalSearchDiscovery: searchViewModel.showsNaturalSearchDiscovery,
          onOpenNaturalSearch: {
            searchViewModel.openNaturalSearch()
          },
          onOpenProfile: { presentAccountSheet(.profile) },
          onOpenSettings: { presentAccountSheet(.settings) },
          onOpenSavedDestination: openJourney,
          onConfigurePlace: { beginSavedDestinationSelection(.place($0)) },
          onAddSavedDestination: { beginSavedDestinationSelection(.destination) },
          onEditPlace: presentPlaceEditor,
          onEditSavedDestination: presentDestinationEditor,
          onManageSavedDestinations: { presentAccountSheet(.favorites) }
        )
        .sheetTabBarVisibility()
      } label: {
        MapShellTab.stations.tabLabel
      }

      Tab(value: .lines) {
        LinesView(viewModel: linesViewModel, accountModel: accountModel)
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
          plannedJourneyDraftModel: plannedJourneyDraftModel,
          journeyNotificationCoordinator: journeyNotificationCoordinator,
          onClose: closeSearch,
          onInspectJourney: { journey in
            journeySheetDetent = expandedDetent
            searchSheetDestination = .journey(journey.id)
          },
          onShowActiveJourney: showActiveJourney,
          onShowPlannedJourney: showPlannedJourney,
          isSelectingSavedDestination: savedDestinationSelectionContext != nil,
          onSelectSavedDestination: selectSavedDestinationResult,
          isSavedDestination: { result in
            accountModel.savedPlace(for: result) != nil
              || accountModel.savedDestination(for: result) != nil
          },
          onEditSavedDestination: presentEditor,
          canAddSavedDestination:
            accountModel.destinations.count < AccountLocalSnapshot.destinationLimit
        )
        .sheetTabBarVisibility()
      }
    }
    .sheet(item: $savedDestinationDraft) { draft in
      SavedDestinationEditorView(
        draft: draft,
        onSave: { label, systemImage in
          save(draft: draft, label: label, systemImage: systemImage)
          savedDestinationDraft = nil
        },
        onChangeDestination: { label, systemImage in
          var replacementDraft = draft
          replacementDraft.label = label
          replacementDraft.systemImage = systemImage
          savedDestinationDraft = nil
          beginSavedDestinationSelection(
            .replacement(replacementDraft),
            preservingReturnDestination: true
          )
        },
        onDelete: deleteAction(for: draft),
        onClose: { savedDestinationDraft = nil }
      )
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
          locationModel: locationModel,
          pushNotificationManager: pushNotificationManager,
          journeyNotificationCoordinator: journeyNotificationCoordinator,
          onReplayOnboarding: onReplayOnboarding,
          notificationInboxRemote: notificationInboxRemote
        )
        .detailSheetPresentation(
          isLargeScreen: isLargeScreen,
          selection: $accountSheetDetent
        )
      case .notifications:
        NotificationSettingsView(
          accountModel: accountModel,
          coordinator: .shared,
          inboxRemote: notificationInboxRemote,
          journeyNotificationCoordinator: journeyNotificationCoordinator
        )
        .detailSheetPresentation(
          isLargeScreen: isLargeScreen,
          selection: $accountSheetDetent
        )
      case .favorites:
        NavigationStack {
          FavoritesSettingsView(
            accountModel: accountModel,
            routesModel: favoriteRoutesModel
          )
        }
        .detailSheetPresentation(
          isLargeScreen: isLargeScreen,
          selection: $accountSheetDetent
        )
      }
    }
    .sheet(item: $searchSheetDestination) { destination in
      switch destination {
      case .journey(let journeyID):
        JourneySheetView(
          journeyID: journeyID,
          searchViewModel: searchViewModel,
          activeJourneyModel: activeJourneyModel,
          plannedJourneyDraftModel: plannedJourneyDraftModel,
          journeyNotificationCoordinator: journeyNotificationCoordinator,
          departureChoicesRepository: journeyDepartureChoicesRepository,
          isLargeScreen: isLargeScreen,
          detent: $journeySheetDetent,
          onExpandMap: { journeySheetDetent = journeyPeekDetent },
          onOpenReport: {
            searchSheetDestination = nil
            activeTab = .report
          }
        )
      case .plannedJourney(let journeyID):
        JourneySheetView(
          journeyID: journeyID,
          searchViewModel: searchViewModel,
          activeJourneyModel: activeJourneyModel,
          plannedJourneyDraftModel: plannedJourneyDraftModel,
          journeyNotificationCoordinator: journeyNotificationCoordinator,
          departureChoicesRepository: journeyDepartureChoicesRepository,
          isPlannedJourney: true,
          isLargeScreen: isLargeScreen,
          detent: $journeySheetDetent,
          onExpandMap: { journeySheetDetent = journeyPeekDetent },
          onOpenReport: {
            searchSheetDestination = nil
            activeTab = .report
          }
        )
      case .scheduledJourney(let journeyID):
        JourneySheetView(
          journeyID: journeyID,
          searchViewModel: searchViewModel,
          activeJourneyModel: activeJourneyModel,
          plannedJourneyDraftModel: plannedJourneyDraftModel,
          journeyNotificationCoordinator: journeyNotificationCoordinator,
          departureChoicesRepository: journeyDepartureChoicesRepository,
          scheduledReminder: journeyNotificationCoordinator.reminder(for: journeyID),
          isLargeScreen: isLargeScreen,
          detent: $journeySheetDetent,
          onExpandMap: { journeySheetDetent = journeyPeekDetent },
          onOpenReport: {
            searchSheetDestination = nil
            activeTab = .report
          }
        )
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if searchViewModel.isNaturalSearchPresented {
        NaturalJourneyComposerView(
          viewModel: searchViewModel,
          onClose: searchViewModel.dismissNaturalSearch
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .transition(
          reduceMotion
            ? .identity
            : .move(edge: .bottom).combined(with: .opacity)
        )
      }
    }
    .animation(
      reduceMotion ? nil : .snappy(duration: 0.3, extraBounce: 0),
      value: searchViewModel.isNaturalSearchPresented
    )
  }

  private var isJourneySheetUp: Bool {
    switch searchSheetDestination {
    case .journey, .plannedJourney, .scheduledJourney: true
    default: false
    }
  }

  private var displayedJourneyPresentation: JourneyMapPresentation? {
    activeJourneyModel.mapPresentation
      ?? plannedJourneyPresentation
      ?? ((activeTab == .search || isJourneySheetUp) ? searchViewModel.mapPresentation : nil)
  }

  private var plannedJourneyPresentation: JourneyMapPresentation? {
    guard case .plannedJourney = searchSheetDestination,
          let journey = plannedJourneyDraftModel.draft?.journey else { return nil }
    return JourneyMapPresentation(journey: journey)
  }

  private var displayedHighlightedSectionID: String? {
    activeJourneyModel.highlightedSectionID
      ?? ((activeTab == .search || isJourneySheetUp)
        ? searchViewModel.highlightedJourneySectionID : nil)
  }

  private func presentAccountSheet(_ destination: AccountSheetDestination) {
    accountSheetDetent = isLargeScreen ? .fraction(0.97) : .large
    accountSheetDestination = destination
  }

  /// Frames the part of the journey that is still ahead when guidance is
  /// running, and the current section otherwise.
  private func frameJourney(sectionID: String?) {
    guard let presentation = displayedJourneyPresentation else { return }
    let mapRect =
      activeJourneyModel.isActive
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

  private func showPlannedJourney() {
    guard let journeyID = plannedJourneyDraftModel.draft?.journey.id else { return }
    activeTab = .search
    journeySheetDetent = expandedDetent
    searchSheetDestination = .plannedJourney(journeyID)
  }

  /// The journey sheet's own peek: taller while guidance runs, where it hosts
  /// the compact strip rather than the squashed panel.
  private var journeyPeekDetent: PresentationDetent {
    JourneySheetDetents.peek(isGuiding: activeJourneyModel.isGuiding)
  }

  private var collapsedDetent: PresentationDetent {
    SheetTabDetents.collapsed(hasCompactContent: activeJourneyModel.isActive)
  }

  private var guidanceDetent: PresentationDetent {
    isLargeScreen ? .fraction(0.97) : .fraction(0.45)
  }

  private var expandedDetent: PresentationDetent {
    DetailSheetPresentation.expanded(isLargeScreen: isLargeScreen)
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
      reportRepository: InMemoryReportRepository(),
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
    plannedJourneyDraftModel: PlannedJourneyDraftModel(),
    reportViewModel: ReportViewModel(
      contextResolver: ReportContextResolver(
        locationModel: locationModel,
        networkRepository: InMemoryNetworkRepository.mapPreview
      ),
      repository: InMemoryReportRepository(),
      searchRepository: InMemorySearchRepository.preview
    ),
    locationModel: locationModel,
    accountModel: accountModel,
    favoriteRoutesModel: FavoriteRoutesModel(
      networkRepository: InMemoryNetworkRepository.mapPreview
    ),
    authSessionViewModel: AuthSessionViewModel(
      client: InMemoryAuthenticationClient(
        session: StoredAuthSession(
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
