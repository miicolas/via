import Foundation
import OSLog
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

enum NaturalSearchState: Sendable, Hashable {
  case dismissed
  case onboarding
  case input
  case loading
  case clarification(draft: NaturalJourneyDraft, field: NaturalJourneyClarification)
  case decision(draft: NaturalJourneyDraft, decision: NaturalJourneyDecision)
  case unsupported(message: String, examples: [String])
  case availability(NaturalJourneyUnavailableGuidance)
  case failed(message: String)
}

enum SearchDepartureSelection: Sendable, Hashable {
  case currentLocation
  case saved(SavedPlace)
  case manual(SearchResult)

  var title: String {
    switch self {
    case .currentLocation:
      "Ma position"
    case .saved(let place):
      place.role.displayTitle
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
  private(set) var naturalSearchState: NaturalSearchState = .dismissed
  private(set) var naturalJourneyCriteria: NaturalJourneyCriteria?
  private(set) var naturalJourneyUnresolvedDraft: NaturalJourneyDraft?
  private(set) var naturalInputErrorMessage: String?
  private(set) var recentSearches: [RecentSearch]
  private(set) var requestedAt: Date? = nil
  private(set) var datetimeRepresents: JourneyDatetimeRepresents = .departure
  private(set) var departureResults: [SearchResult] = []
  private(set) var departureLoadState: SearchLoadState = .idle
  /// One-shot signal: a natural-language search resolved to this journey, so
  /// the shell can close the IA sheet and open the journey sheet on it.
  private(set) var naturalResultJourneyID: JourneyID?

  var query = ""
  var departureQuery = ""
  var naturalQuery = ""

  @ObservationIgnored private let repository: any SearchRepository
  @ObservationIgnored private let journeyRepository: any JourneyRepository
  @ObservationIgnored private let locationModel: LocationModel
  @ObservationIgnored private let account: AccountModel?
  @ObservationIgnored private let recentSearchStore: any RecentSearchStoring
  @ObservationIgnored private let filterStore: any SearchFilterStoring
  @ObservationIgnored private let naturalJourneyRepository: (any NaturalJourneyRepository)?
  @ObservationIgnored private let naturalLanguageAvailability:
    @Sendable () -> NaturalLanguageAvailability
  @ObservationIgnored private let naturalJourneyOnboardingStore: any NaturalJourneyOnboardingStoring
  @ObservationIgnored private let naturalJourneyMetrics: any NaturalJourneyMetricsRecording
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private var searchTask: Task<Void, Never>?
  @ObservationIgnored private var journeyTask: Task<Void, Never>?
  @ObservationIgnored private var naturalCriteriaReplanTask: Task<Void, Never>?
  @ObservationIgnored private var naturalJourneyTask: Task<Void, Never>?
  @ObservationIgnored private var departureSearchTask: Task<Void, Never>?
  @ObservationIgnored private var lastNaturalJourneyRequest: NaturalJourneyRequest?
  @ObservationIgnored private var naturalSearchStartedAt: Date?
  @ObservationIgnored private var naturalCorrectionCount = 0
  @ObservationIgnored private var lastSearchedQuery = ""
  @ObservationIgnored private var lastDepartureSearchedQuery = ""

  init(
    repository: any SearchRepository,
    journeyRepository: any JourneyRepository,
    locationModel: LocationModel,
    account: AccountModel? = nil,
    naturalJourneyRepository: (any NaturalJourneyRepository)? = nil,
    naturalLanguageAvailability: @escaping @Sendable () -> NaturalLanguageAvailability = {
      .unavailable(.deviceNotEligible)
    },
    naturalJourneyOnboardingStore: (any NaturalJourneyOnboardingStoring)? = nil,
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
    self.naturalJourneyRepository = naturalJourneyRepository
    self.naturalLanguageAvailability = naturalLanguageAvailability
    self.naturalJourneyOnboardingStore =
      naturalJourneyOnboardingStore
      ?? UserDefaultsNaturalJourneyOnboardingStore()
    self.naturalJourneyMetrics = naturalJourneyMetrics
    self.now = now
  }

  var naturalLanguageAccess: NaturalLanguageAccess {
    naturalLanguageAvailability().access
  }

  var isNaturalSearchPresented: Bool {
    naturalSearchState != .dismissed
  }

  var showsNaturalSearchDiscovery: Bool {
    naturalLanguageAccess == .active && !naturalJourneyOnboardingStore.hasSeenOnboarding
  }

  func openNaturalSearch() {
    naturalInputErrorMessage = nil
    switch naturalLanguageAccess {
    case .hidden:
      return
    case .explanation(let guidance):
      naturalSearchState = .availability(guidance)
    case .active:
      // This is an express entry point: opening it must always put the
      // keyboard and the actual task one tap away, including on first use.
      naturalJourneyOnboardingStore.markOnboardingSeen()
      naturalSearchState = .input
    }
  }

  func showNaturalSearchInput() {
    naturalJourneyOnboardingStore.markOnboardingSeen()
    naturalSearchState = .input
  }

  func dismissNaturalSearch() {
    if naturalSearchState == .onboarding {
      naturalJourneyOnboardingStore.markOnboardingSeen()
    }
    clearNaturalSearch()
  }

  /// Everything the natural-language surface owns, back to its resting
  /// state. Kept in one place so a new natural-search property cannot be
  /// forgotten by one of the three callers that tear the surface down.
  private func clearNaturalSearch() {
    naturalJourneyTask?.cancel()
    naturalQuery = ""
    naturalInputErrorMessage = nil
    lastNaturalJourneyRequest = nil
    naturalSearchState = .dismissed
  }

  /// Clears the one-shot journey signal once the shell has opened the sheet.
  func consumeNaturalResultJourney() {
    naturalResultJourneyID = nil
  }

  func retryNaturalSearch() {
    guard let lastNaturalJourneyRequest else { return }
    performNaturalRequest(lastNaturalJourneyRequest)
  }

  func retryNaturalAvailability() {
    if let lastNaturalJourneyRequest {
      performNaturalRequest(lastNaturalJourneyRequest)
    } else {
      openNaturalSearch()
    }
  }

  func submitNaturalSearch() {
    let phrase = naturalQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard naturalLanguageAccess == .active,
      !phrase.isEmpty,
      naturalJourneyRepository != nil
    else { return }

    naturalSearchStartedAt = now()
    naturalCorrectionCount = 0
    naturalJourneyCriteria = nil
    naturalJourneyUnresolvedDraft = nil
    naturalInputErrorMessage = nil
    performNaturalRequest(
      .submit(
        query: phrase,
        currentLocation: locationModel.coordinate,
      ))
  }

  func resolveNaturalPlace(
    draft: NaturalJourneyDraft,
    field: NaturalJourneyClarification,
    candidate: SearchResult,
  ) {
    guard field.candidates.contains(candidate) else { return }
    let origin = field.target == .origin ? candidate : nil
    let destination = field.target == .destination ? candidate : nil
    guard origin != nil || destination != nil else { return }
    naturalCorrectionCount += 1
    performNaturalRequest(
      .resolve(
        draft: draft,
        currentLocation: locationModel.coordinate,
        origin: origin,
        destination: destination,
        requestedAt: nil,
        datetimeRepresents: nil,
      ))
  }

  func resolveNaturalTime(
    draft: NaturalJourneyDraft,
    requestedAt: Date? = nil,
    represents: JourneyDatetimeRepresents,
  ) {
    naturalCorrectionCount += 1
    performNaturalRequest(
      .resolve(
        draft: draft,
        currentLocation: locationModel.coordinate,
        origin: nil,
        destination: nil,
        requestedAt: requestedAt,
        datetimeRepresents: represents,
      ))
  }

  func resolveNaturalModeConflict(
    draft: NaturalJourneyDraft,
    mode: TransitMode,
    keeping: NaturalJourneyModeConstraint,
  ) {
    naturalCorrectionCount += 1
    performNaturalRequest(
      .resolveModeConflict(
        draft: draft,
        currentLocation: locationModel.coordinate,
        mode: mode,
        keeping: keeping,
      ))
  }

  func confirmNaturalCurrentLocation(draft: NaturalJourneyDraft) {
    guard let coordinate = locationModel.coordinate else { return }
    naturalCorrectionCount += 1
    performNaturalRequest(
      .confirmCurrentLocation(
        draft: draft,
        currentLocation: coordinate,
      ))
  }

  func resolveNaturalTimeConflict(
    draft: NaturalJourneyDraft,
    keeping constraint: RouteTimeConstraint,
  ) {
    naturalCorrectionCount += 1
    performNaturalRequest(
      .resolveTimeConflict(
        draft: draft,
        currentLocation: locationModel.coordinate,
        keeping: constraint,
      ))
  }

  func continueNaturalSearchWithoutUnsupportedConstraints(draft: NaturalJourneyDraft) {
    naturalCorrectionCount += 1
    performNaturalRequest(
      .continueWithoutUnsupportedConstraints(
        draft: draft,
        currentLocation: locationModel.coordinate,
      ))
  }

  func modifyNaturalQuery() {
    lastNaturalJourneyRequest = nil
    naturalInputErrorMessage = nil
    naturalSearchState = .input
  }

  func naturalQueryDidChange() {
    naturalInputErrorMessage = nil
  }

  func useNaturalSuggestion(_ suggestion: String) {
    naturalQuery = suggestion
    naturalInputErrorMessage = nil
    if naturalSearchState != .input {
      lastNaturalJourneyRequest = nil
      naturalSearchState = .input
    }
  }

  func useClassicSearch() {
    clearNaturalSearch()
    naturalJourneyCriteria = nil
    naturalJourneyUnresolvedDraft = nil
    editDestination()
    clearQuery()
  }

  private func performNaturalRequest(_ request: NaturalJourneyRequest) {
    guard let naturalJourneyRepository else { return }
    lastNaturalJourneyRequest = request
    naturalJourneyTask?.cancel()
    naturalSearchState = .loading
    naturalJourneyTask = Task { [weak self] in
      guard let self else { return }
      do {
        let result = try await naturalJourneyRepository.submit(request)
        guard !Task.isCancelled else { return }
        receiveNaturalJourneyResult(result)
      } catch is CancellationError {
      } catch let error as NaturalIntentParsingError {
        guard !Task.isCancelled else { return }
        AppLog.ai.error(
          "natural_interpretation_failed reason=\(String(describing: error), privacy: .public)",
        )
        recordNaturalMetric(.failure)
        switch error {
        case .modelNotReady:
          naturalSearchState = .availability(.modelNotReady)
        case .modelFailed:
          naturalSearchState = .availability(.systemUnavailable)
        case .cancelled:
          lastNaturalJourneyRequest = nil
          break
        default:
          lastNaturalJourneyRequest = nil
          naturalInputErrorMessage = Self.naturalInputErrorMessage(for: error)
          naturalSearchState = .input
        }
      } catch {
        guard !Task.isCancelled else { return }
        recordNaturalMetric(.failure)
        naturalSearchState = .failed(message: Self.offlineMessage)
      }
    }
  }

  private func receiveNaturalJourneyResult(_ result: NaturalJourneyResult) {
    switch result {
    case .ready(let interpretation, let journeys):
      recordNaturalMetric(.success)
      apply(interpretation)
      results = []
      loadState = .idle
      journeyResult = journeys
      highlightedJourneySectionID = nil
      if let firstJourney = journeys.journeys.first {
        selectJourney(firstJourney)
        step = .results
        naturalResultJourneyID = firstJourney.id
      } else {
        mapPresentation = nil
        step = journeys.status == .unavailable ? .unavailable : .noRoute
      }
      naturalSearchState = .dismissed
      naturalQuery = ""
      lastNaturalJourneyRequest = nil
    case .needsClarification(let draft, let fields):
      recordNaturalMetric(.clarification)
      guard let field = fields.first else {
        naturalSearchState = .failed(message: "La demande doit être précisée.")
        return
      }
      naturalSearchState = .clarification(draft: draft, field: field)
    case .needsDecision(let draft, let decision):
      recordNaturalMetric(.clarification)
      naturalSearchState = .decision(draft: draft, decision: decision)
    case .networkUnavailable(let interpretation):
      recordNaturalMetric(.failure)
      apply(interpretation)
      naturalSearchState = .failed(message: Self.offlineMessage)
    case .networkUnavailableDraft(let draft):
      recordNaturalMetric(.failure)
      naturalJourneyCriteria = nil
      naturalJourneyUnresolvedDraft = draft
      naturalSearchState = .failed(message: Self.offlineMessage)
    case .unsupported(let message, let examples):
      recordNaturalMetric(.unsupported)
      naturalSearchState = .unsupported(message: message, examples: examples)
    case .unavailable(let message):
      recordNaturalMetric(.unavailable)
      naturalSearchState = .failed(message: message)
    }
  }

  /// Hands a finished interpretation to the classic search surface, so the
  /// sheet and the map agree on what was understood.
  private func apply(_ interpretation: NaturalJourneyInterpretation) {
    naturalJourneyCriteria = NaturalJourneyCriteria(interpretation)
    naturalJourneyUnresolvedDraft = nil
    selectedDestination = interpretation.destinationResult
    selectedDeparture =
      interpretation.originResult.map(SearchDepartureSelection.manual)
      ?? .currentLocation
    query = interpretation.destinationResult.name
  }

  /// The single sentence shown under the composer field. The state speaks when
  /// it has a question or a refusal; otherwise the last transport error does.
  var naturalInputMessage: String? {
    switch naturalSearchState {
    case .clarification(_, let field):
      field.question
    case .unsupported(let message, _), .failed(let message):
      message
    case .availability(let guidance):
      guidance.message
    case .dismissed, .onboarding, .input, .loading, .decision:
      naturalInputErrorMessage
    }
  }

  private static let offlineMessage = "Connexion nécessaire pour rechercher les horaires."

  private static func naturalInputErrorMessage(
    for error: NaturalIntentParsingError,
  ) -> String {
    switch error {
    case .unsupportedLanguage:
      "Utilise une phrase en français."
    case .modelBusy:
      "Apple Intelligence est occupé. Réessaie dans un instant."
    case .contextWindowExceeded:
      "Raccourcis ta demande."
    case .contentRefused:
      "Reformule ta demande de trajet."
    case .invalidResponse, .modelFailed:
      "Je n’ai pas compris. Vérifie les lieux et l’heure."
    case .cancelled, .modelNotReady:
      "La demande n’a pas pu être interprétée."
    }
  }

  private func recordNaturalMetric(_ outcome: NaturalJourneyMetric.Outcome) {
    guard let naturalSearchStartedAt else { return }
    let duration = max(0, now().timeIntervalSince(naturalSearchStartedAt))
    naturalJourneyMetrics.recordSearch(
      NaturalJourneyMetric(
        outcome: outcome,
        firstResultDurationMilliseconds: outcome == .success
          ? Int(duration * 1000)
          : nil,
        correctionCount: naturalCorrectionCount,
      ))
  }

  var subtitle: String {
    "Depuis \(selectedDeparture.title)"
  }

  var savedPlaces: [SavedPlace] {
    account?.places ?? []
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

    clearNaturalSearch()
    naturalJourneyCriteria = nil
    naturalJourneyUnresolvedDraft = nil
    naturalResultJourneyID = nil
    naturalSearchStartedAt = nil
    naturalCorrectionCount = 0
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
    naturalCorrectionCount += 1
    criteria.requestedAt = requestedAt
    criteria.datetimeRepresents = represents
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
    naturalCorrectionCount += 1
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

      var request = JourneyRequest(
        origin: origin,
        destination: JourneyPlaceSelection(selectedDestination).journeyDestination,
      )
      request.limit = 4
      request.requiresAccessibleStations = filters.requiresAccessibleStations
      request.requiresOperationalElevators = filters.requiresOperationalElevators
      if case .manual(.station(let station)) = selectedDeparture {
        request.originStationID = station.id
      }
      if var criteria = naturalJourneyCriteria {
        criteria.originLabel = selectedDeparture.title
        criteria.destinationResult = selectedDestination
        naturalJourneyCriteria = criteria
        request.requestedAt = criteria.requestedAt
        request.datetimeRepresents = criteria.datetimeRepresents
        request.requiredModes = criteria.requiredModes
        request.excludedModes = criteria.excludedModes
        request.preferredModes = criteria.preferredModes
      } else if let requestedAt {
        request.requestedAt = requestedAt
        request.datetimeRepresents = datetimeRepresents
      }

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
    case .saved, .manual:
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

