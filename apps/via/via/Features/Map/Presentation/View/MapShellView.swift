import MapKit
import SwiftUI

/// Root screen: full-screen map with a persistent bottom sheet hosting the
/// Stations / Lignes / Signaler / Recherche tabs, Find My style.
struct MapShellView: View {
  let networkViewModel: NetworkViewModel
  let stationsViewModel: StationsViewModel
  let nearbyStationsModel: NearbyStationsModel
  let linesViewModel: LinesViewModel
  let selectedStationModel: SelectedStationModel
  let searchViewModel: SearchViewModel
  /// The natural-language conversation; the shell hosts its composer and
  /// navigates on its one-shot outcome.
  let naturalJourneyDialogue: NaturalJourneyDialogue
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
  let journeyShareRepository: any JourneyShareRepository
  let meetupsModel: MeetupsModel
  let friendsModel: FriendsModel
  /// The single funnel deep links and push routes arrive through.
  let routeInbox: RouteInbox
  let journeyDepartureChoicesRepository: any JourneyDepartureChoicesRepository
  /// Replays the first run from the root, offered inside Réglages.
  let onReplayOnboarding: @MainActor () -> Void
  let notificationInboxRemote: any NotificationInboxRemote
  /// One resolver for the journey the map draws; the journey sheets share it.
  private let journeyContextSource: JourneyContextSource

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var showTabSheet: Bool = true
  @State private var activeTab: MapShellTab = .stations
  @State private var previousTab: MapShellTab = .stations
  /// Owns the map camera; the shell only forwards the events that move it.
  @State private var cameraDirector: JourneyCameraDirector
  @State private var selectedMapStation: StationMapItem?
  @State private var selectedBikeStation: BikeStation?
  @State private var selectedSharedMobility: SharedMobilityItem?

  @State private var isLargeScreen: Bool = false
  // The reference opens with the map still visible above the content sheet.
  @State private var activeDetent: PresentationDetent = .fraction(0.45)
  /// Where the sheet rested before a natural-search panel raised it.
  @State private var detentBeforeNaturalPanel: PresentationDetent?
  @State private var detailSheetDetent: PresentationDetent = .height(80)
  @State private var accountSheetDestination: AccountSheetDestination?
  @State private var accountSheetDetent: PresentationDetent = .height(80)
  @State private var favoritesFocus: FavoritesFocus?
  @State private var journeyShareRoute: JourneyShareRoute?
  @State private var showsMeetupInvitation = false
  @State private var showsFriendInvitation = false
  // Journey details use one stacked sheet slot above the tab sheet.
  @State private var searchSheetDestination: SearchSheetDestination?
  @State private var journeySheetDetent: PresentationDetent = .large
  @State private var savedDestinationSelectionContext: SavedDestinationSelectionContext?
  @State private var savedDestinationDraft: SavedDestinationDraft?
  @State private var returnsToPreviousTabAfterSavingDestination = false
  @State private var reportOpenTick = 0
  @State private var meetupOpenTick = 0

  init(
    networkViewModel: NetworkViewModel,
    stationsViewModel: StationsViewModel,
    nearbyStationsModel: NearbyStationsModel,
    linesViewModel: LinesViewModel,
    selectedStationModel: SelectedStationModel,
    searchViewModel: SearchViewModel,
    naturalJourneyDialogue: NaturalJourneyDialogue,
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
    journeyShareRepository: any JourneyShareRepository = InMemoryJourneyShareRepository(),
    meetupsModel: MeetupsModel,
    friendsModel: FriendsModel,
    routeInbox: RouteInbox = RouteInbox(),
    journeyDepartureChoicesRepository: any JourneyDepartureChoicesRepository =
      InMemoryJourneyDepartureChoicesRepository.unavailable,
    onReplayOnboarding: @escaping @MainActor () -> Void = {},
    notificationInboxRemote: any NotificationInboxRemote = NoOpNotificationInboxRemote()
  ) {
    self.networkViewModel = networkViewModel
    self.stationsViewModel = stationsViewModel
    self.nearbyStationsModel = nearbyStationsModel
    self.linesViewModel = linesViewModel
    self.selectedStationModel = selectedStationModel
    self.searchViewModel = searchViewModel
    self.naturalJourneyDialogue = naturalJourneyDialogue
    self.activeJourneyModel = activeJourneyModel
    self.plannedJourneyDraftModel = plannedJourneyDraftModel
    self.reportViewModel = reportViewModel
    self.locationModel = locationModel
    _cameraDirector = State(
      initialValue: JourneyCameraDirector(openingCoordinate: locationModel.coordinate)
    )
    journeyContextSource = JourneyContextSource(
      searchViewModel: searchViewModel,
      plannedJourneyDraftModel: plannedJourneyDraftModel,
      journeyNotificationCoordinator: journeyNotificationCoordinator,
      activeJourneyModel: activeJourneyModel
    )
    self.accountModel = accountModel
    self.favoriteRoutesModel = favoriteRoutesModel
    self.authSessionViewModel = authSessionViewModel
    self.profileModel = profileModel
    self.pushNotificationManager = pushNotificationManager
    self.journeyNotificationCoordinator = journeyNotificationCoordinator
    self.journeyShareRepository = journeyShareRepository
    self.meetupsModel = meetupsModel
    self.friendsModel = friendsModel
    self.routeInbox = routeInbox
    self.journeyDepartureChoicesRepository = journeyDepartureChoicesRepository
    self.onReplayOnboarding = onReplayOnboarding
    self.notificationInboxRemote = notificationInboxRemote
  }

  var body: some View {
    appEventMap
      // Journey sheets disappear in the same update that opens Signaler, so
      // the cue belongs to this root view that survives the transition.
      .haptic(Haptic.commit, on: reportOpenTick)
      .haptic(Haptic.commit, on: meetupOpenTick)
  }

  private var presentedMap: some View {
    map
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
  }

  private var journeyEventMap: some View {
    presentedMap
    .task {
      guard locationModel.coordinate == nil else { return }
      locationModel.requestLocation()
    }
    .onChange(of: locationModel.coordinate) { _, coordinate in
      cameraDirector.locationChanged(
        coordinate,
        tracking: journeyTrackingCamera,
        reducesMotion: reduceMotion
      )
    }
    .onChange(of: cameraDirector.position) { _, newPosition in
      guard newPosition.positionedByUser else { return }
      cameraDirector.travellerMoved()
    }
    .onChange(of: activeJourneyModel.isTracking, initial: true) { _, isTracking in
      cameraDirector.trackingChanged(
        isTracking: isTracking,
        tracking: journeyTrackingCamera,
        reducesMotion: reduceMotion
      )
    }
    .onChange(of: activeJourneyModel.currentSectionIndex) { _, _ in
      cameraDirector.sectionChanged(
        tracking: journeyTrackingCamera,
        journeyFrame: journeyFrame(for: activeJourneyModel.highlightedSectionID),
        reducesMotion: reduceMotion
      )
    }
    .onChange(of: reduceMotion) { _, reducesMotion in
      cameraDirector.motionChanged(
        tracking: journeyTrackingCamera,
        reducesMotion: reducesMotion
      )
    }
    // Selection is cleared on the next line, so the trigger is the tap itself:
    // a pin taken under the thumb, and the journey surface leaving for good.
    // Every map annotation enters through selectedMapStation. Keeping the cue
    // here avoids a second buzz when the selected item is then routed to a
    // Vélib’ or shared-mobility sheet.
    .haptic(Haptic.commit, on: selectedMapStation != nil) { !$0 && $1 }
    .haptic(Haptic.ended, on: activeJourneyModel.hasSurface) { $0 && !$1 }
    .onChange(of: selectedMapStation) { _, newValue in
      guard let newValue else { return }
      // Clear right away so re-tapping the same annotation reopens the sheet.
      selectedMapStation = nil
      activeTab = .stations
      presentStation(newValue)
    }
    .onChange(of: displayedJourneyPresentation) { _, presentation in
      cameraDirector.presentationChanged(
        isTracking: activeJourneyModel.isTracking,
        tracking: journeyTrackingCamera,
        mapRect: presentation?.mapRect,
        reducesMotion: reduceMotion
      )
    }
    .onChange(of: displayedHighlightedSectionID) { _, sectionID in
      guard !activeJourneyModel.isTracking else { return }
      cameraDirector.frame(journeyFrame(for: sectionID))
    }
    .onChange(of: activeDetent) { _, detent in
      // Collapsing the sheet used to leave the running journey off
      // screen with nothing to bring it back.
      guard detent == collapsedDetent,
            activeJourneyModel.isActive,
            !activeJourneyModel.isTracking else { return }
      cameraDirector.frame(journeyFrame(for: displayedHighlightedSectionID))
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
    .onChange(of: naturalJourneyDialogue.outcome) { _, outcome in
      guard let outcome else { return }
      switch outcome {
      case .journey(let journeyID):
        activeTab = .search
        journeySheetDetent = expandedDetent
        searchSheetDestination = .journey(journeyID)
      case .lineStatus(let navigation):
        linesViewModel.requestNaturalLineStatus(navigation)
        activeTab = .lines
      }
      naturalJourneyDialogue.consumeOutcome()
    }
    .onChange(of: activeJourneyModel.isActive) { _, isActive in
      // Once guidance is running, peek so the map behind stays visible.
      if isActive { journeySheetDetent = journeyPeekDetent }
    }
  }

  private var appEventMap: some View {
    journeyEventMap
    .onChange(of: searchSheetDestination) { _, destination in
      // Reset the detent so the next journey opens expanded, not on the peek.
      if destination == nil { journeySheetDetent = expandedDetent }
    }
    .onChange(of: activeTab) { oldValue, newValue in
      if newValue == .search, oldValue != .search, oldValue != .report {
        // Signaler is reached *from* search (the guidance panel's
        // report button) and search comes back on its own for the
        // running journey, so remembering it sent closing search
        // straight back into the report form.
        previousTab = oldValue
      }
      if let detent = MapShellPresentation.detentAfterTabChange(
        from: oldValue,
        to: newValue,
        isLargeScreen: isLargeScreen,
        hasJourneySurface: activeJourneyModel.hasSurface
      ) {
        activeDetent = detent
      }
    }
    .onGeometryChange(for: Bool.self) {
      $0.size.width > 600
    } action: { newValue in
      // Remap detents before the size class flips so the sheet lands on a valid one.
      let remapped = MapShellPresentation.remapDetents(
        .init(active: activeDetent, detail: detailSheetDetent, journey: journeySheetDetent),
        isLargeScreen: newValue,
        collapsed: collapsedDetent,
        journeyPeek: journeyPeekDetent,
        detailCollapsed: .height(DetailSheetPresentation.collapsedHeight)
      )
      activeDetent = remapped.active
      detailSheetDetent = remapped.detail
      journeySheetDetent = remapped.journey
      isLargeScreen = newValue
    }
    .task(id: authSessionViewModel.session?.user.id) {
      if let user = authSessionViewModel.session?.user {
        profileModel.activate(scope: .user(user.id), seedName: user.displayName)
      } else {
        profileModel.activate(scope: .anonymous)
      }
    }
    // The shell consumes the inbox as soon as it exists, so a link that
    // arrived during onboarding presents on first appearance.
    .onChange(of: routeInbox.pending, initial: true) { _, _ in
      guard let pending = routeInbox.consume() else { return }
      route(pending)
    }
    .onChange(of: naturalJourneyDialogue.state) { oldState, newState in
      // A question or an answer needs room the collapsed sheet does not have;
      // the detent it interrupted comes back once the conversation moves on.
      let wasPanel = NaturalJourneyPresentationPolicy.showsPanel(oldState)
      let isPanel = NaturalJourneyPresentationPolicy.showsPanel(newState)
      switch MapShellPresentation.naturalPanelTransition(
        wasVisible: wasPanel,
        isVisible: isPanel
      ) {
      case .present:
        detentBeforeNaturalPanel = activeDetent
        activeDetent = MapShellPresentation.naturalPanelDetent(isLargeScreen: isLargeScreen)
      case .dismiss:
        if let detentBeforeNaturalPanel {
          activeDetent = detentBeforeNaturalPanel
        }
        detentBeforeNaturalPanel = nil
      case nil:
        break
      }
    }
    .overlay {
      if journeyScreenBeamIsVisible {
        JourneyScreenBeamView()
          .transition(reduceMotion ? .identity : .opacity)
      }
    }
    .animation(
      reduceMotion ? nil : .smooth(duration: 0.45),
      value: journeyScreenBeamIsVisible
    )
    .aiScreenGlow(naturalGlowIntensity)
  }

  private var map: some View {
    @Bindable var cameraDirector = cameraDirector
    return NetworkMapView(
      viewModel: networkViewModel,
      position: $cameraDirector.position,
      nearby: nearbyStationsModel,
      stationSelectionEnabled: activeTab != .search && searchSheetDestination == nil,
      journeyPresentation: displayedJourneyPresentation,
      highlightedJourneySegmentID: displayedHighlightedSectionID,
      journeyTracking: journeyTrackingCamera.map { _ in
        JourneyTrackingControl(
          isFollowing: cameraDirector.followsLocation,
          recenter: recenterJourneyTrackingCamera
        )
      },
      selectedStation: $selectedMapStation
    )
  }

  /// The Siri-style edge light: quiet while the traveller types, swelling
  /// while Metyro thinks, and absent when a panel needs the attention.
  private var naturalGlowIntensity: AIScreenGlowView.Intensity? {
    switch naturalJourneyDialogue.state {
    case .input:
      .ambient
    case .loading:
      .thinking
    case .dismissed, .onboarding, .clarification, .decision, .unsupported, .availability,
      .failed:
      nil
    }
  }

  /// The beam is an explicit loss-of-signal cue. Normal tracking uses only
  /// MapKit's native user annotation and controls.
  private var journeyScreenBeamIsVisible: Bool {
    activeJourneyModel.isTracking
      && (activeJourneyModel.isOffline || !activeJourneyModel.hasLiveLocationFix)
  }

  /// Opens the detail sheet for a map item. A dock and a transit station own
  /// the same sheet slot, so selecting one always clears the other — the
  /// invariant lives here rather than at each entry point.
  private func presentStation(_ item: StationMapItem) {
    if item.sharedMobilityCluster != nil {
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
        cameraDirector.position = .region(
          MKCoordinateRegion(
            center: item.coordinate.clLocationCoordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
          )
        )
      }
      return
    }
    detailSheetDetent = isLargeScreen ? .fraction(0.97) : .large
    if let sharedMobility = item.sharedMobility {
      selectedStationModel.dismiss()
      selectedBikeStation = nil
      selectedSharedMobility = sharedMobility
    } else if let bikeStation = item.dock {
      selectedStationModel.dismiss()
      selectedSharedMobility = nil
      selectedBikeStation = bikeStation
    } else {
      selectedSharedMobility = nil
      selectedBikeStation = nil
      selectedStationModel.select(item)
    }
  }

  /// Picking a row is what actually moves the camera: applying a filter never
  /// does more than tighten, so this is the gesture that says "take me there".
  private func revealStation(_ item: StationMapItem) {
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
      cameraDirector.position = .region(
        MKCoordinateRegion(
          center: item.coordinate.clLocationCoordinate,
          latitudinalMeters: 600,
          longitudinalMeters: 600
        )
      )
    }
    presentStation(item)
  }

  private func closeSearch() {
    savedDestinationSelectionContext = nil
    savedDestinationDraft = nil
    returnsToPreviousTabAfterSavingDestination = false
    searchViewModel.resetSearch()
    activeTab = previousTab
  }

  private func openReportFromJourney() {
    reportOpenTick &+= 1
    searchSheetDestination = nil
    activeTab = .report
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
    savedDestinationDraft = SavedDestinationEditing.draft(
      for: result,
      context: context,
      in: accountModel
    )
  }

  private func presentEditor(_ result: SearchResult) {
    returnsToPreviousTabAfterSavingDestination = false
    savedDestinationDraft = SavedDestinationEditing.draft(for: result, in: accountModel)
  }

  private func presentPlaceEditor(_ place: SavedPlace) {
    savedDestinationDraft = SavedDestinationEditing.draft(editing: place)
  }

  private func presentDestinationEditor(_ destination: SavedDestination) {
    savedDestinationDraft = SavedDestinationEditing.draft(editing: destination)
  }

  private func save(draft: SavedDestinationDraft, label: String, systemImage: String) {
    SavedDestinationEditing.save(
      draft,
      label: label,
      systemImage: systemImage,
      in: accountModel
    )

    if returnsToPreviousTabAfterSavingDestination {
      searchViewModel.resetSearch()
      activeTab = previousTab
    }
    returnsToPreviousTabAfterSavingDestination = false
  }

  private func deleteAction(for draft: SavedDestinationDraft) -> (() -> Void)? {
    SavedDestinationEditing.deleteAction(for: draft, in: accountModel)
  }

  /// The one presentation switch for every deep link, whichever door it came
  /// through — universal link, custom scheme, or push notification.
  private func route(_ route: MapRoute) {
    switch route {
    case .notifications:
      presentAccountSheet(.notifications)
    case .line(let routeID):
      activeTab = .lines
      linesViewModel.requestRoute(routeID)
    case .station(let stationID):
      activeTab = .stations
      if let item = networkViewModel.stationMapItem(for: stationID) {
        presentStation(item)
      }
    case .scheduledJourney(let journeyID):
      Task { await routeScheduledJourney(journeyID) }
    case .activeJourney(let journeyID):
      Task { await routeActiveJourney(journeyID) }
    case .sharedJourney(let token):
      journeyShareRoute = JourneyShareRoute(token: token)
    case .meetup(let meetupID):
      guard MeetupFeatureFlags.rendezVousEnabled else { return }
      Task {
        await meetupsModel.open(meetupId: meetupID)
        presentAccountSheet(.meetups)
      }
    case .meetupInvitation(let token, let key):
      guard MeetupFeatureFlags.rendezVousEnabled else { return }
      Task {
        await meetupsModel.prepareInvitation(token: token, key: key)
        showsMeetupInvitation = true
      }
    case .friendInvitation(let token):
      guard MeetupFeatureFlags.rendezVousEnabled else { return }
      Task {
        await friendsModel.prepareInvitation(token: token)
        showsFriendInvitation = true
      }
    }
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
      && !naturalJourneyDialogue.isPresented
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
        || selectedBikeStation != nil
        || selectedSharedMobility != nil
        || reportViewModel.isPresentingAnotherSheet || accountSheetDestination != nil
        || searchSheetDestination != nil || savedDestinationDraft != nil,
      hidesTabBar: naturalJourneyDialogue.isPresented,
      locksExpandedDetent: isNaturalJourneyOnboardingVisible,
      reservesCompactSpace: activeJourneyModel.isActive,
      isCompactVisible: isActiveJourneyCompactVisible,
      compactContent: { journeyCompact }
    ) {
      Tab(value: .stations) {
        StationsView(
          viewModel: stationsViewModel,
          nearby: nearbyStationsModel,
          selectedStation: selectedStationModel,
          accountModel: accountModel,
          isLargeScreen: $isLargeScreen,
          detailDetent: $detailSheetDetent,
          profileModel: profileModel,
          onSelectNearby: revealStation,
          onOpenSearch: { activeTab = .search },
          naturalLanguageAccess: naturalJourneyDialogue.access,
          showsNaturalSearchDiscovery: naturalJourneyDialogue.showsDiscovery,
          onOpenNaturalSearch: {
            naturalJourneyDialogue.open()
          },
          onOpenProfile: { presentAccountSheet(.profile) },
          onOpenMeetups: { presentAccountSheet(.meetups) },
          onOpenFriends: { presentAccountSheet(.friends) },
          onOpenSettings: { presentAccountSheet(.settings) },
          onMeetAtStation: openMeetupComposer,
          onOpenSavedDestination: openJourney,
          onConfigurePlace: { presentFavorites(focus: .place($0)) },
          onAddSavedDestination: { presentFavorites(focus: .addDestination) },
          onEditPlace: presentPlaceEditor,
          onEditSavedDestination: presentDestinationEditor,
          onManageSavedDestinations: { presentFavorites(focus: nil) }
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
          dialogue: naturalJourneyDialogue,
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
            accountModel.destinations.count < AccountLocalSnapshot.destinationLimit,
          onConfigurePlace: { beginSavedDestinationSelection(.place($0)) },
          onAddSavedDestination: { beginSavedDestinationSelection(.destination) },
          onClearPlace: { accountModel.removePlace(for: $0) },
          onRemoveSavedDestination: { accountModel.removeDestination(id: $0) },
          onManageSavedDestinations: { presentFavorites(focus: nil) }
        )
        .sheetTabBarVisibility()
      }
    }
    .accessibilityHidden(isNaturalJourneyOnboardingVisible)
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
    .sheet(item: $selectedBikeStation) { station in
      BikeStationDetailView(
        station: station,
        isLargeScreen: isLargeScreen,
        detailDetent: $detailSheetDetent,
        onPlanJourney: {
          selectedBikeStation = nil
          openJourney(station.searchResult)
        }
      )
    }
    .sheet(item: $selectedSharedMobility) { item in
      switch item {
      case .station(let dock):
        // The same screen the Vélib' layer opens, with the same actions: which
        // route delivered the dock is not something the traveller should feel.
        BikeStationDetailView(
          station: dock.station,
          isLargeScreen: isLargeScreen,
          detailDetent: $detailSheetDetent,
          onPlanJourney: {
            selectedSharedMobility = nil
            openJourney(dock.station.searchResult)
          }
        )
      case .vehicle(let vehicle):
        SharedMobilityDetailView(
          vehicle: vehicle,
          distanceMeters: locationModel.coordinate.map {
            vehicle.coordinate.metersAway(from: $0)
          },
          isLargeScreen: isLargeScreen,
          detailDetent: $detailSheetDetent
        )
      }
    }
    .sheet(item: $accountSheetDestination, onDismiss: { favoritesFocus = nil }) { destination in
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
            routesModel: favoriteRoutesModel,
            searchViewModel: searchViewModel,
            focus: favoritesFocus
          )
        }
        .detailSheetPresentation(
          isLargeScreen: isLargeScreen,
          selection: $accountSheetDetent
        )
      case .meetups:
        MeetupsView(
          model: meetupsModel,
          friendsModel: friendsModel,
          isSignedIn: authSessionViewModel.isSignedIn,
          profile: profileModel,
          savedOrigins: savedMeetupOrigins
        )
        .detailSheetPresentation(
          isLargeScreen: isLargeScreen,
          selection: $accountSheetDetent
        )
      case .friends:
        FriendsView(
          model: friendsModel,
          authSessionViewModel: authSessionViewModel
        )
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
          journeyShareRepository: journeyShareRepository,
          departureChoicesRepository: journeyDepartureChoicesRepository,
          journeyContextSource: journeyContextSource,
          isLargeScreen: isLargeScreen,
          detent: $journeySheetDetent,
          onExpandMap: { journeySheetDetent = journeyPeekDetent },
          onOpenReport: openReportFromJourney
        )
      case .plannedJourney(let journeyID):
        JourneySheetView(
          journeyID: journeyID,
          searchViewModel: searchViewModel,
          activeJourneyModel: activeJourneyModel,
          plannedJourneyDraftModel: plannedJourneyDraftModel,
          journeyNotificationCoordinator: journeyNotificationCoordinator,
          journeyShareRepository: journeyShareRepository,
          departureChoicesRepository: journeyDepartureChoicesRepository,
          journeyContextSource: journeyContextSource,
          isPlannedJourney: true,
          isLargeScreen: isLargeScreen,
          detent: $journeySheetDetent,
          onExpandMap: { journeySheetDetent = journeyPeekDetent },
          onOpenReport: openReportFromJourney
        )
      case .scheduledJourney(let journeyID):
        JourneySheetView(
          journeyID: journeyID,
          searchViewModel: searchViewModel,
          activeJourneyModel: activeJourneyModel,
          plannedJourneyDraftModel: plannedJourneyDraftModel,
          journeyNotificationCoordinator: journeyNotificationCoordinator,
          journeyShareRepository: journeyShareRepository,
          departureChoicesRepository: journeyDepartureChoicesRepository,
          journeyContextSource: journeyContextSource,
          scheduledReminder: journeyNotificationCoordinator.reminder(for: journeyID),
          isLargeScreen: isLargeScreen,
          detent: $journeySheetDetent,
          onExpandMap: { journeySheetDetent = journeyPeekDetent },
          onOpenReport: openReportFromJourney
        )
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if naturalJourneyDialogue.isPresented && !isNaturalJourneyOnboardingVisible {
        NaturalJourneyComposerView(
          dialogue: naturalJourneyDialogue,
          criteria: searchViewModel.naturalJourneyCriteria,
          onClose: naturalJourneyDialogue.dismiss
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
    .overlay {
      if isNaturalJourneyOnboardingVisible {
        AIOnboardingCard(
          onTry: naturalJourneyDialogue.showInput,
          onClose: naturalJourneyDialogue.dismiss
        )
        .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
      }
    }
    .animation(
      reduceMotion ? nil : .snappy(duration: 0.3, extraBounce: 0),
      value: naturalJourneyDialogue.isPresented
    )
    .animation(
      reduceMotion ? nil : .smooth(duration: 0.35),
      value: isNaturalJourneyOnboardingVisible
    )
    .sheet(item: $journeyShareRoute) { route in
      JourneyShareSheetView(
        token: route.token,
        repository: journeyShareRepository,
        onClose: { journeyShareRoute = nil }
      )
    }
    .sheet(isPresented: $showsMeetupInvitation) {
      MeetupInvitationView(
        model: meetupsModel,
        profile: profileModel,
        savedOrigins: savedMeetupOrigins
      )
    }
    .sheet(isPresented: $showsFriendInvitation) {
      FriendInvitationView(
        model: friendsModel,
        authSessionViewModel: authSessionViewModel
      )
    }
  }

  private var isJourneySheetUp: Bool {
    switch searchSheetDestination {
    case .journey, .plannedJourney, .scheduledJourney: true
    default: false
    }
  }

  private var isNaturalJourneyOnboardingVisible: Bool {
    naturalJourneyDialogue.state == .onboarding
  }

  private var displayedJourneyPresentation: JourneyMapPresentation? {
    activeJourneyModel.mapPresentation
      ?? journeyContext.map { JourneyMapPresentation(journey: $0.journey) }
  }

  /// The trajet surface the shell is presenting, as the context source needs
  /// it: a dedicated sheet wins over the search tab.
  private var journeySurface: JourneyContextSource.Surface {
    if let searchSheetDestination {
      .sheet(searchSheetDestination)
    } else if activeTab == .search {
      .search
    } else {
      .hidden
    }
  }

  private var journeyContext: JourneyContext? {
    journeyContextSource.current(for: journeySurface)
  }

  private var displayedHighlightedSectionID: String? {
    journeyContextSource.highlightedSectionID(for: journeySurface)
  }

  private func presentAccountSheet(_ destination: AccountSheetDestination) {
    accountSheetDetent = isLargeScreen ? .fraction(0.97) : .large
    accountSheetDestination = destination
  }

  private var savedMeetupOrigins: [MeetupOrigin] {
    accountModel.places.map { MeetupOrigin(result: $0.searchResult, favorite: true) }
      + accountModel.destinations.map { MeetupOrigin(result: $0.searchResult, favorite: true) }
  }

  private func openMeetupComposer(at station: StationOverview) {
    meetupOpenTick += 1
    meetupsModel.composeDestination = MeetupStation(station)
    selectedStationModel.dismiss()
    Task { @MainActor in
      await Task.yield()
      presentAccountSheet(.meetups)
    }
  }

  /// Configuring a shortcut is a settings job, so the rail opens Favorites
  /// rather than sending the user off to the search tab.
  private func presentFavorites(focus: FavoritesFocus?) {
    favoritesFocus = focus
    presentAccountSheet(.favorites)
  }

  /// The rect framing one selected section of the displayed journey.
  private func journeyFrame(for sectionID: String?) -> MKMapRect? {
    displayedJourneyPresentation?.mapRect(for: sectionID)
  }

  private var journeyTrackingCamera: JourneyTrackingCamera? {
    guard activeJourneyModel.isTracking,
          let journey = activeJourneyModel.journey,
          let sectionIndex = activeJourneyModel.currentSectionIndex,
          journey.sections.indices.contains(sectionIndex),
          let coordinate = locationModel.coordinate
    else { return nil }

    return JourneyTrackingCamera(
      section: journey.sections[sectionIndex],
      userCoordinate: coordinate
    )
  }

  private func recenterJourneyTrackingCamera() {
    cameraDirector.recenter(
      tracking: journeyTrackingCamera,
      reducesMotion: reduceMotion
    )
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
  let filterStore = StationMapFilterStore()
  let nearbyStationsModel = NearbyStationsModel(
    repository: InMemoryNetworkRepository.mapPreview,
    filterStore: filterStore
  )
  let meetupRepository = InMemoryMeetupRepository()
  let meetupCryptography = MeetupCryptoVault()
  let meetupLive = MeetupLiveCoordinator(
    transport: meetupRepository,
    cryptography: meetupCryptography,
    locationModel: locationModel
  )
  let searchViewModel = SearchViewModel(
    repository: InMemorySearchRepository.preview,
    journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
    locationModel: locationModel,
    account: accountModel
  )

  MapShellView(
    networkViewModel: NetworkViewModel(
      repository: InMemoryNetworkRepository.mapPreview,
      filterStore: filterStore,
      nearby: nearbyStationsModel
    ),
    stationsViewModel: StationsViewModel(
      locationModel: locationModel,
      networkRepository: InMemoryNetworkRepository.mapPreview,
      departuresRepository: departures,
      nearby: nearbyStationsModel
    ),
    nearbyStationsModel: nearbyStationsModel,
    linesViewModel: LinesViewModel(repository: PreviewLineStatusRepository()),
    selectedStationModel: SelectedStationModel(
      departuresRepository: departures,
      crowdingRepository: InMemoryStationCrowdingRepository(crowding: .preview),
      reportRepository: InMemoryReportRepository(),
      account: accountModel,
      locationModel: locationModel
    ),
    searchViewModel: searchViewModel,
    naturalJourneyDialogue: NaturalJourneyDialogue(
      locationModel: locationModel,
      planner: searchViewModel
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
    profileModel: ProfileModel(store: InMemoryProfileStore()),
    meetupsModel: MeetupsModel(
      repository: meetupRepository,
      searchRepository: InMemorySearchRepository.preview,
      locationModel: locationModel,
      live: meetupLive
    ),
    friendsModel: FriendsModel(repository: InMemoryFriendsRepository())
  )
}
