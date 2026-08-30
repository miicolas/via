import Foundation
import Observation

enum SearchViewStep: Sendable, Equatable {
  case destination
  case planning
  case results
  case noRoute
  case unavailable
  case locationBlocked(LocationAuthorization)
  case failed(ViaError)
}

enum SearchLoadState: Sendable, Equatable {
  case idle
  case loading
  case loaded
  case empty
  case failed(ViaError)
}

enum SearchDepartureSelection: Sendable, Hashable {
  case currentLocation
  case saved(SavedPlace)
  case savedDestination(SavedDestination)
  case manual(SearchResult)

  var title: String {
    switch self {
    case .currentLocation:
      "Ma position"
    case .saved(let place):
      place.role.displayTitle
    case .savedDestination(let destination):
      destination.label
    case .manual(let result):
      result.name
    }
  }

  var subtitle: String? {
    switch self {
    case .currentLocation:
      "Position actuelle"
    case .saved(let place):
      place.name == place.role.displayTitle ? "Lieu enregistré" : place.name
    case .savedDestination(let destination):
      destination.label == destination.name ? "Lieu enregistré" : destination.name
    case .manual(let result):
      result.subtitle
    }
  }

  var coordinate: GeoCoordinate? {
    switch self {
    case .currentLocation:
      nil
    case .saved(let place):
      place.coordinate
    case .savedDestination(let destination):
      destination.coordinate
    case .manual(let result):
      result.coordinate
    }
  }

  var shortcut: StationPlaceShortcut? {
    guard case .saved(let place) = self else {
      return self == .currentLocation ? StationPlaceShortcut.currentLocation : nil
    }

    switch place.role {
    case .home: return .home
    case .work: return .work
    }
  }

  var isCurrentLocation: Bool {
    if case .currentLocation = self { return true }
    return false
  }
}

@MainActor
@Observable
final class SearchViewModel {
  private(set) var step: SearchViewStep = .destination
  private(set) var results: [SearchResult] = []
  private(set) var loadState: SearchLoadState = .idle
  private(set) var journeyResult: JourneyResult?
  private(set) var mapPresentation: JourneyMapPresentation?
  private(set) var selectedDestination: SearchResult?
  private(set) var selectedDeparture: SearchDepartureSelection = .currentLocation
  private(set) var highlightedJourneySectionID: String?
  private(set) var filters: SearchFilters
  private(set) var accessibilitySource = SearchResponse.AccessibilitySource(
    status: .unavailable,
    sourceUpdatedAt: nil,
    importedAt: nil
  )
  private(set) var elevatorSource = SearchResponse.ElevatorSource(
    status: .unavailable,
    sourceUpdatedAt: nil,
    importedAt: nil
  )
  /// What a finished natural-language interpretation established, kept here
  /// because journey planning reads and rewrites it. `NaturalJourneyDialogue`
  /// owns the conversation that produces it.
  private(set) var naturalJourneyCriteria: NaturalJourneyCriteria?
  private(set) var recentSearches: [RecentSearch]
  private(set) var requestedAt: Date? = nil
  private(set) var datetimeRepresents: JourneyDatetimeRepresents = .departure
  private(set) var departureResults: [SearchResult] = []
  private(set) var departureLoadState: SearchLoadState = .idle

  var query = ""
  var departureQuery = ""

  @ObservationIgnored private let repository: any SearchRepository
  @ObservationIgnored private let journeyRepository: any JourneyRepository
  @ObservationIgnored private let locationModel: LocationModel
  @ObservationIgnored private let account: AccountModel?
  @ObservationIgnored private let recentSearchStore: any RecentSearchStoring
  @ObservationIgnored private let filterStore: any SearchFilterStoring
  @ObservationIgnored private let naturalLanguageAvailability:
    @Sendable () -> NaturalLanguageAvailability
  @ObservationIgnored private let naturalJourneyMetrics: any NaturalJourneyMetricsRecording
  /// Corrections to a natural search, shared with the dialogue so both halves
  /// report one number. See `NaturalJourneyCorrectionTally`.
  @ObservationIgnored let naturalCorrections = NaturalJourneyCorrectionTally()
  /// Installed by `NaturalJourneyDialogue` at construction so `resetSearch()`
  /// also tears down the conversation surface the dialogue owns.
  @ObservationIgnored var tearDownNaturalSearch: (@MainActor () -> Void)?
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private var searchTask: Task<Void, Never>?
  @ObservationIgnored private var journeyTask: Task<Void, Never>?
  @ObservationIgnored private var naturalCriteriaReplanTask: Task<Void, Never>?
  @ObservationIgnored private var departureSearchTask: Task<Void, Never>?
  @ObservationIgnored private var lastSearchedQuery = ""
  @ObservationIgnored private var lastDepartureSearchedQuery = ""

  init(
    repository: any SearchRepository,
    journeyRepository: any JourneyRepository,
    locationModel: LocationModel,
    account: AccountModel? = nil,
    naturalLanguageAvailability: @escaping @Sendable () -> NaturalLanguageAvailability = {
      .unavailable(.deviceNotEligible)
    },
    naturalJourneyMetrics: any NaturalJourneyMetricsRecording = AppLogNaturalJourneyMetrics(),
    now: @escaping @Sendable () -> Date = { .now },
    filterStore: any SearchFilterStoring = UserDefaultsSearchFilterStore(),
    recentSearchStore: any RecentSearchStoring = UserDefaultsRecentSearchStore(),
  ) {
    self.repository = repository
    self.journeyRepository = journeyRepository
    self.locationModel = locationModel
    self.account = account
    self.recentSearchStore = recentSearchStore
    recentSearches = recentSearchStore.load()
    self.filterStore = filterStore
    filters = filterStore.load()
    self.naturalLanguageAvailability = naturalLanguageAvailability
    self.naturalJourneyMetrics = naturalJourneyMetrics
    self.now = now
  }

  var naturalLanguageAccess: NaturalLanguageAccess {
    naturalLanguageAvailability().access
  }

  /// A fresh phrase starts a new understanding: whatever criteria the last
  /// answer produced no longer describes what is being asked.
  func clearNaturalCriteria() {
    naturalJourneyCriteria = nil
  }

  /// The dialogue's hand-off: a finished interpretation lands on the classic
  /// search surface, so the sheet and the map agree on what was understood.
  /// `journeys` carries the locally planned result; it is nil when the
  /// interpretation finished but planning could not run (offline).
  func applyNaturalInterpretation(
    _ interpretation: NaturalJourneyInterpretation,
    journeys: JourneyResult?,
  ) {
    naturalJourneyCriteria = NaturalJourneyCriteria(interpretation)
    selectedDestination = interpretation.destinationResult
    selectedDeparture =
      interpretation.originResult.map(SearchDepartureSelection.manual)
      ?? .currentLocation
    query = interpretation.destinationResult.name

    guard let journeys else { return }
    results = []
    loadState = .idle
    journeyResult = journeys
    highlightedJourneySectionID = nil
    if let firstJourney = journeys.journeys.first {
      selectJourney(firstJourney)
      step = .results
    } else {
      mapPresentation = nil
      step = journeys.status == .unavailable ? .unavailable : .noRoute
    }
  }

  /// « Recherche classique » from a natural-language dead end: back to the
  /// destination field with nothing pre-filled.
  func exitNaturalSearch() {
    naturalJourneyCriteria = nil
    editDestination()
    clearQuery()
  }

  func recordNaturalIncorrectExecution() {
    guard let criteria = naturalJourneyCriteria else { return }
    naturalJourneyMetrics.recordSearch(NaturalJourneyMetric(
      outcome: .incorrectExecution,
      firstResultDurationMilliseconds: nil,
      correctionCount: naturalCorrections.count,
      processingPath: criteria.processingPath,
    ))
  }

  var subtitle: String {
    "Depuis \(selectedDeparture.title)"
  }

  var savedPlaces: [SavedPlace] {
    account?.places ?? []
  }

  var savedDestinations: [SavedDestination] {
    account?.destinations.sorted { $0.position < $1.position } ?? []
  }

  var selectedJourneyID: JourneyID? {
    mapPresentation?.id
  }

  var selectedJourney: Journey? {
    guard let selectedJourneyID else { return nil }
    return journeyResult?.journeys.first { $0.id == selectedJourneyID }
  }

  var journeyDestination: JourneyDestination? {
    selectedDestination.map { JourneyPlaceSelection($0).journeyDestination }
  }

  var journeyRequestedAt: Date? {
    naturalJourneyCriteria?.requestedAt ?? requestedAt
  }

  var journeyPlanningPolicy: JourneyPlanningPolicy {
    JourneyPlanningPolicy(
      requiredModes: naturalJourneyCriteria?.requiredModes ?? [],
      excludedModes: naturalJourneyCriteria?.excludedModes ?? [],
      preferredModes: naturalJourneyCriteria?.preferredModes ?? [],
      requiresAccessibleStations: filters.requiresAccessibleStations,
      requiresOperationalElevators: filters.requiresOperationalElevators
    )
  }

  /// A departure revision preserves identity, so every search surface can be
  /// swapped together without dismissing and rebuilding the detail sheet.
  func replaceJourney(_ journey: Journey) {
    guard let result = journeyResult,
      result.journeys.contains(where: { $0.id == journey.id })
    else { return }
    let journeys = result.journeys.map { $0.id == journey.id ? journey : $0 }
    journeyResult = JourneyResult(
      status: result.status,
      source: result.source,
      generatedAt: .now,
      journeys: journeys,
      reason: result.reason
    )
    if selectedJourneyID == journey.id {
      mapPresentation = JourneyMapPresentation(journey: journey)
    }
  }

  /// Replans the opened itinerary around one of its two boundary times.
  ///
  /// Departure and arrival are different backend constraints: subtracting the
  /// old duration locally would miss a different service, wait or transfer.
  /// The closest journey with the same line sequence is preferred when it is
  /// still available, then the planner's recommended result is used.
  func reviseJourneySchedule(
    _ journey: Journey,
    destination: JourneyDestination,
    policy: JourneyPlanningPolicy,
    requestedAt: Date,
    represents: JourneyDatetimeRepresents
  ) async throws -> Journey {
    guard let firstSection = journey.sections.first else {
      throw JourneyScheduleRevisionError.unavailable
    }

    let request = JourneyRequest(
      origin: firstSection.from.coordinate,
      destination: destination,
      policy: policy,
      requestedAt: requestedAt,
      datetimeRepresents: represents,
      originStationID: firstSection.kind == .transit
        ? firstSection.stops.first?.stationID
        : nil
    )

    let result = try await journeyRepository.plan(request)
    switch result.status {
    case .noRoute:
      throw JourneyScheduleRevisionError.noRoute
    case .unavailable:
      throw JourneyScheduleRevisionError.unavailable
    case .ready:
      break
    }

    let routeSequence = journey.sections.compactMap { $0.route?.id }
    let candidate = result.journeys.first {
      $0.sections.compactMap { $0.route?.id } == routeSequence
    } ?? result.journeys.first
    guard let candidate else {
      throw JourneyScheduleRevisionError.noRoute
    }

    if journeyResult?.journeys.contains(where: { $0.id == journey.id }) == true {
      if var criteria = naturalJourneyCriteria {
        naturalCorrections.increment()
        criteria.requestedAt = requestedAt
        criteria.datetimeRepresents = represents
        criteria.timeAnchor = nil
        naturalJourneyCriteria = criteria
      } else {
        self.requestedAt = requestedAt
        datetimeRepresents = represents
      }
    }

    return candidate.identified(as: journey.id)
  }

  var canResetSearch: Bool {
    step != .destination
      || !query.isEmpty
      || !results.isEmpty
      || loadState != .idle
      || selectedDestination != nil
      || selectedDeparture != .currentLocation
      || requestedAt != nil
      || naturalJourneyCriteria != nil
  }

  var showsRecentSearches: Bool {
    step == .destination
      && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && loadState == .idle
      && !visibleRecentSearches.isEmpty
  }

  var showsRecentDepartureSearches: Bool {
    departureQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && departureLoadState == .idle
      && !recentSearches.isEmpty
  }

  var visibleRecentSearches: [RecentSearch] {
    guard filters.bikeStationsOnly else { return recentSearches }
    return recentSearches.filter { $0.kind == .bikeStation }
  }

  func updateQuery(_ value: String) {
    guard step == .destination else { return }

    query = value
    searchTask?.cancel()

    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalized.count >= 2 else {
      results = []
      loadState = .idle
      lastSearchedQuery = ""
      return
    }

    searchTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(250))
      } catch {
        return
      }

      guard !Task.isCancelled, let self else { return }
      await performSearch(normalized)
    }
  }

  func updateDepartureQuery(_ value: String) {
    departureQuery = value
    departureSearchTask?.cancel()
    departureResults = []
    departureLoadState = .idle

    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalized.count >= 2 else {
      lastDepartureSearchedQuery = ""
      return
    }

    departureSearchTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(250))
      } catch {
        return
      }

      guard !Task.isCancelled, let self else { return }
      await performDepartureSearch(normalized)
    }
  }

  /// Enter chooses the first loaded destination. If suggestions are still
  /// pending, it finishes that destination search and selects its first
  /// result as soon as it arrives.
  func searchImmediately() {
    guard step == .destination else { return }

    if loadState == .loaded, let firstResult = results.first {
      selectDestination(firstResult)
      return
    }

    searchTask?.cancel()
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalized.count >= 2 else { return }

    searchTask = Task { [weak self] in
      guard !Task.isCancelled, let self else { return }
      await performSearch(normalized)

      guard !Task.isCancelled,
        loadState == .loaded,
        let firstResult = results.first
      else { return }
      selectDestination(firstResult)
    }
  }

  func retry() {
    let retryQuery =
      lastSearchedQuery.isEmpty
      ? query.trimmingCharacters(in: .whitespacesAndNewlines)
      : lastSearchedQuery

    guard retryQuery.count >= 2, step == .destination else { return }
    startSearch(retryQuery)
  }

  /// Replaces whatever destination search is in flight with an immediate one.
  /// `updateQuery` is the debounced door; this is the one every other trigger
  /// (retry, a filter change) goes through.
  private func startSearch(_ normalizedQuery: String) {
    searchTask?.cancel()
    searchTask = Task { [weak self] in
      guard !Task.isCancelled, let self else { return }
      await performSearch(normalizedQuery)
    }
  }

  func retryDepartureSearch() {
    let retryQuery =
      lastDepartureSearchedQuery.isEmpty
      ? departureQuery.trimmingCharacters(in: .whitespacesAndNewlines)
      : lastDepartureSearchedQuery

    guard retryQuery.count >= 2 else { return }
    departureSearchTask?.cancel()
    departureSearchTask = Task { [weak self] in
      guard !Task.isCancelled, let self else { return }
      await performDepartureSearch(retryQuery)
    }
  }

  func clearQuery() {
    updateQuery("")
  }

  func clearDepartureSearch() {
    departureSearchTask?.cancel()
    departureQuery = ""
    departureResults = []
    departureLoadState = .idle
    lastDepartureSearchedQuery = ""
  }

  /// Starts a genuinely new search while preserving user preferences such
  /// as accessibility filters and saved places.
  func resetSearch() {
    searchTask?.cancel()
    journeyTask?.cancel()
    naturalCriteriaReplanTask?.cancel()

    step = .destination
    results = []
    loadState = .idle
    accessibilitySource = SearchResponse.AccessibilitySource(
      status: .unavailable,
      sourceUpdatedAt: nil,
      importedAt: nil
    )
    elevatorSource = SearchResponse.ElevatorSource(
      status: .unavailable,
      sourceUpdatedAt: nil,
      importedAt: nil
    )
    journeyResult = nil
    mapPresentation = nil
    selectedDestination = nil
    selectedDeparture = .currentLocation
    highlightedJourneySectionID = nil
    query = ""

    tearDownNaturalSearch?()
    naturalJourneyCriteria = nil
    naturalCorrections.reset()
    lastSearchedQuery = ""
    requestedAt = nil
    datetimeRepresents = .departure
    clearDepartureSearch()
  }

  func setRequiresAccessibleStations(_ enabled: Bool) {
    updateFilters { $0.requiresAccessibleStations = enabled }
  }

  func setRequiresOperationalElevators(_ enabled: Bool) {
    updateFilters { $0.requiresOperationalElevators = enabled }
  }

  func setBikeStationsOnly(_ enabled: Bool) {
    guard updateFilters({ $0.bikeStationsOnly = enabled }), step == .destination else { return }
    // Which places the query can even match just changed, so the list on
    // screen is stale — re-run it, or clear it when there is nothing to run.
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalized.count >= 2 else {
      searchTask?.cancel()
      results = []
      loadState = .idle
      return
    }
    startSearch(normalized)
  }

  /// Persists a filter change and re-plans when one is on screen.
  /// Returns whether anything actually changed.
  @discardableResult
  private func updateFilters(_ update: (inout SearchFilters) -> Void) -> Bool {
    var next = filters
    update(&next)
    guard next != filters else { return false }
    filters = next
    filterStore.save(next)

    if selectedDestination != nil, step != .destination {
      planJourney()
    }
    return true
  }

  func selectDestination(_ result: SearchResult) {
    searchTask?.cancel()
    recentSearches = recentSearchStore.upsert(RecentSearch(result: result, savedAt: now()))
    selectedDestination = result
    results = []
    loadState = .idle
    planJourney()
  }

  func selectRecentSearch(_ recent: RecentSearch) {
    selectDestination(recent.searchResult)
  }

  func removeRecentSearch(id: String) {
    recentSearches = recentSearchStore.remove(id: id)
  }

  func clearRecentSearches() {
    recentSearches = recentSearchStore.clear()
  }

  func editDestination() {
    searchTask?.cancel()
    journeyTask?.cancel()
    let editingQuery =
      query.isEmpty
      ? (lastSearchedQuery.isEmpty ? selectedDestination?.name ?? "" : lastSearchedQuery)
      : query
    selectedDestination = nil
    journeyResult = nil
    mapPresentation = nil
    highlightedJourneySectionID = nil
    query = editingQuery
    results = []
    loadState = .idle
    step = .destination
  }

  func selectDeparture(_ departure: SearchDepartureSelection) {
    selectedDeparture = departure
    guard selectedDestination != nil, step != .destination else { return }
    planJourney()
  }

  func editDeparture() {
    selectedDeparture = .currentLocation
    guard selectedDestination != nil, step != .destination else { return }
    planJourney()
  }

  func retryJourney() {
    guard selectedDestination != nil else { return }
    planJourney()
  }

  func updateTime(_ requestedAt: Date, represents: JourneyDatetimeRepresents) {
    self.requestedAt = requestedAt
    datetimeRepresents = represents

    guard selectedDestination != nil, step != .destination else { return }
    planJourney()
  }

  func updateNaturalTime(_ requestedAt: Date, represents: JourneyDatetimeRepresents) {
    guard var criteria = naturalJourneyCriteria else { return }
    naturalCorrections.increment()
    criteria.requestedAt = requestedAt
    criteria.datetimeRepresents = represents
    criteria.timeAnchor = nil
    naturalJourneyCriteria = criteria
    scheduleNaturalCriteriaReplan()
  }

  func updateNaturalModes(
    required: Set<TransitMode>,
    excluded: Set<TransitMode>,
    preferred: Set<TransitMode>,
  ) {
    guard required.isDisjoint(with: excluded),
      required.isDisjoint(with: preferred),
      excluded.isDisjoint(with: preferred),
      var criteria = naturalJourneyCriteria
    else { return }
    naturalCorrections.increment()
    criteria.requiredModes = required
    criteria.excludedModes = excluded
    criteria.preferredModes = preferred
    naturalJourneyCriteria = criteria
    scheduleNaturalCriteriaReplan()
  }

  func selectJourney(_ journey: Journey) {
    guard journeyResult?.journeys.contains(where: { $0.id == journey.id }) == true else {
      return
    }
    mapPresentation = JourneyMapPresentation(journey: journey)
    highlightedJourneySectionID = nil
  }

  func highlightJourneySection(_ sectionID: String?) {
    guard let sectionID else {
      highlightedJourneySectionID = nil
      return
    }
    guard selectedJourney?.sections.contains(where: { $0.id == sectionID }) == true else { return }
    highlightedJourneySectionID = sectionID
  }

  func searchPlaces(query: String) async throws -> SearchResponse {
    try await repository.search(
      query: query,
      near: locationModel.coordinate
    )
  }

  private func planJourney() {
    guard let selectedDestination else { return }

    journeyTask?.cancel()
    journeyResult = nil
    mapPresentation = nil
    highlightedJourneySectionID = nil
    step = .planning

    journeyTask = Task { [weak self] in
      guard let self else { return }

      guard let origin = await resolveOrigin() else {
        guard !Task.isCancelled else { return }
        step = .locationBlocked(locationModel.authorization)
        return
      }

      guard !Task.isCancelled else { return }

      var requestedAtForRequest: Date? = nil
      var datetimeRepresentsForRequest: JourneyDatetimeRepresents? = nil
      var timeAnchorForRequest: JourneyTimeAnchor? = nil
      var policy = JourneyPlanningPolicy(
        requiresAccessibleStations: filters.requiresAccessibleStations,
        requiresOperationalElevators: filters.requiresOperationalElevators
      )
      if var criteria = naturalJourneyCriteria {
        criteria.originLabel = selectedDeparture.title
        criteria.destinationResult = selectedDestination
        naturalJourneyCriteria = criteria
        requestedAtForRequest = criteria.requestedAt
        datetimeRepresentsForRequest = criteria.datetimeRepresents
        timeAnchorForRequest = criteria.timeAnchor
        policy = JourneyPlanningPolicy(
          requiredModes: criteria.requiredModes,
          excludedModes: criteria.excludedModes,
          preferredModes: criteria.preferredModes,
          requiresAccessibleStations: filters.requiresAccessibleStations,
          requiresOperationalElevators: filters.requiresOperationalElevators
        )
      } else if let requestedAt {
        requestedAtForRequest = requestedAt
        datetimeRepresentsForRequest = datetimeRepresents
      }
      let originStationID: StationID? = if case .manual(.station(let station)) = selectedDeparture {
        station.id
      } else {
        nil
      }
      let request = JourneyRequest(
        origin: origin,
        destination: JourneyPlaceSelection(selectedDestination).journeyDestination,
        policy: policy,
        requestedAt: requestedAtForRequest,
        datetimeRepresents: datetimeRepresentsForRequest,
        timeAnchor: timeAnchorForRequest,
        originStationID: originStationID
      )

      do {
        let result = try await journeyRepository.plan(request)
        guard !Task.isCancelled else { return }

        journeyResult = result
        switch result.status {
        case .ready where !result.journeys.isEmpty:
          if let firstJourney = result.journeys.first {
            selectJourney(firstJourney)
          }
          step = .results
        case .noRoute, .ready:
          step = .noRoute
        case .unavailable:
          step = .unavailable
        }
      } catch is CancellationError {
      } catch {
        guard !Task.isCancelled else { return }
        step = .failed(error.via)
      }
    }
  }

  private func scheduleNaturalCriteriaReplan() {
    naturalCriteriaReplanTask?.cancel()
    naturalCriteriaReplanTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(180))
      } catch {
        return
      }
      guard !Task.isCancelled, let self else { return }
      planJourney()
    }
  }

  private func resolveOrigin() async -> GeoCoordinate? {
    switch selectedDeparture {
    case .currentLocation:
      await locationModel.requestCurrentLocation()
    case .saved, .savedDestination, .manual:
      selectedDeparture.coordinate
    }
  }

  private func performSearch(_ normalizedQuery: String) async {
    loadState = .loading
    lastSearchedQuery = normalizedQuery

    do {
      let response = try await repository.search(
        query: normalizedQuery,
        near: locationModel.coordinate,
        bikeStationsOnly: filters.bikeStationsOnly,
      )
      guard !Task.isCancelled else { return }

      results = response.results
      accessibilitySource = response.accessibilitySource
      elevatorSource = response.elevatorSource
      loadState = response.results.isEmpty && filters.bikeStationsOnly
        && response.bikeSource == .unavailable
        ? .failed(.unavailable)
        : (response.results.isEmpty ? .empty : .loaded)
    } catch is CancellationError {
    } catch {
      guard !Task.isCancelled else { return }
      loadState = .failed(error.via)
    }
  }

  private func performDepartureSearch(_ normalizedQuery: String) async {
    departureLoadState = .loading
    lastDepartureSearchedQuery = normalizedQuery

    do {
      let response = try await searchPlaces(query: normalizedQuery)
      guard !Task.isCancelled else { return }

      departureResults = response.results
      accessibilitySource = response.accessibilitySource
      elevatorSource = response.elevatorSource
      departureLoadState = response.results.isEmpty ? .empty : .loaded
    } catch is CancellationError {
    } catch {
      guard !Task.isCancelled else { return }
      departureLoadState = .failed(error.via)
    }
  }
}
