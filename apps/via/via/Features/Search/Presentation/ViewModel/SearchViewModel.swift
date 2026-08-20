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

enum NaturalSearchState: Sendable, Hashable {
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
        case let .saved(place):
            place.role.displayTitle
        case let .manual(result):
            result.name
        }
    }

    var subtitle: String? {
        switch self {
        case .currentLocation:
            "Position actuelle"
        case let .saved(place):
            place.name == place.role.displayTitle ? "Lieu enregistré" : place.name
        case let .manual(result):
            result.departureSearchSubtitle
        }
    }

    var coordinate: GeoCoordinate? {
        switch self {
        case .currentLocation:
            nil
        case let .saved(place):
            place.coordinate
        case let .manual(result):
            result.coordinate
        }
    }

    var shortcut: StationPlaceShortcut? {
        guard case let .saved(place) = self else {
            return self == .currentLocation ? StationPlaceShortcut.currentLocation : nil
        }

        switch place.role {
        case .home: return .home
        case .work: return .work
        case .favorite: return nil
        }
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
    private(set) var isNaturalSearchPresented = false
    private(set) var naturalSearchState: NaturalSearchState = .input
    private(set) var naturalJourneyCriteria: NaturalJourneyCriteria?

    var query = ""
    var naturalQuery = ""

    @ObservationIgnored private let repository: any SearchRepository
    @ObservationIgnored private let journeyRepository: any JourneyRepository
    @ObservationIgnored private let locationModel: LocationModel
    @ObservationIgnored private let account: AccountModel?
    @ObservationIgnored private let naturalJourneyRepository: (any NaturalJourneyRepository)?
    @ObservationIgnored private let naturalLanguageAvailability: @Sendable () -> NaturalLanguageAvailability
    @ObservationIgnored private let naturalJourneyOnboardingStore: any NaturalJourneyOnboardingStoring
    @ObservationIgnored private let naturalJourneyMetrics: any NaturalJourneyMetricsRecording
    @ObservationIgnored private let metricsNow: @Sendable () -> Date
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var journeyTask: Task<Void, Never>?
    @ObservationIgnored private var naturalCriteriaReplanTask: Task<Void, Never>?
    @ObservationIgnored private var naturalJourneyTask: Task<Void, Never>?
    @ObservationIgnored private var lastNaturalJourneyRequest: NaturalJourneyRequest?
    @ObservationIgnored private var naturalSearchStartedAt: Date?
    @ObservationIgnored private var naturalCorrectionCount = 0
    @ObservationIgnored private var lastSearchedQuery = ""

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
        metricsNow: @escaping @Sendable () -> Date = { .now }
    ) {
        self.repository = repository
        self.journeyRepository = journeyRepository
        self.locationModel = locationModel
        self.account = account
        self.naturalJourneyRepository = naturalJourneyRepository
        self.naturalLanguageAvailability = naturalLanguageAvailability
        self.naturalJourneyOnboardingStore = naturalJourneyOnboardingStore
            ?? UserDefaultsNaturalJourneyOnboardingStore()
        self.naturalJourneyMetrics = naturalJourneyMetrics
        self.metricsNow = metricsNow
    }

    var naturalLanguageAccess: NaturalLanguageAccess {
        naturalLanguageAvailability().access
    }

    var showsNaturalSearchDiscovery: Bool {
        naturalLanguageAccess == .active && !naturalJourneyOnboardingStore.hasSeenOnboarding
    }

    func openNaturalSearch() {
        switch naturalLanguageAccess {
        case .hidden:
            return
        case let .explanation(guidance):
            naturalSearchState = .availability(guidance)
        case .active:
            naturalSearchState = naturalJourneyOnboardingStore.hasSeenOnboarding
                ? .input
                : .onboarding
        }
        isNaturalSearchPresented = true
    }

    func showNaturalSearchInput() {
        naturalJourneyOnboardingStore.markOnboardingSeen()
        naturalSearchState = .input
    }

    func dismissNaturalSearch() {
        if naturalSearchState == .onboarding {
            naturalJourneyOnboardingStore.markOnboardingSeen()
        }
        naturalJourneyTask?.cancel()
        naturalQuery = ""
        lastNaturalJourneyRequest = nil
        isNaturalSearchPresented = false
    }

    func retryNaturalSearch() {
        guard let lastNaturalJourneyRequest else { return }
        performNaturalRequest(lastNaturalJourneyRequest)
    }

    func submitNaturalSearch() {
        let phrase = naturalQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard naturalLanguageAccess == .active,
              !phrase.isEmpty,
              naturalJourneyRepository != nil else { return }

        naturalSearchStartedAt = metricsNow()
        naturalCorrectionCount = 0
        performNaturalRequest(.submit(
            query: phrase,
            currentLocation: locationModel.coordinate
        ))
    }

    func resolveNaturalPlace(
        draft: NaturalJourneyDraft,
        field: NaturalJourneyClarification,
        candidate: SearchResult
    ) {
        guard field.candidates.contains(candidate) else { return }
        let origin = field.target == .origin ? candidate : nil
        let destination = field.target == .destination ? candidate : nil
        guard origin != nil || destination != nil else { return }
        naturalCorrectionCount += 1
        performNaturalRequest(.resolve(
            draft: draft,
            currentLocation: locationModel.coordinate,
            origin: origin,
            destination: destination,
            requestedAt: nil,
            datetimeRepresents: nil
        ))
    }

    func resolveNaturalTime(
        draft: NaturalJourneyDraft,
        requestedAt: Date? = nil,
        represents: JourneyDatetimeRepresents
    ) {
        naturalCorrectionCount += 1
        performNaturalRequest(.resolve(
            draft: draft,
            currentLocation: locationModel.coordinate,
            origin: nil,
            destination: nil,
            requestedAt: requestedAt,
            datetimeRepresents: represents
        ))
    }

    func resolveNaturalModeConflict(
        draft: NaturalJourneyDraft,
        mode: TransitMode,
        keeping: NaturalJourneyModeConstraint
    ) {
        naturalCorrectionCount += 1
        performNaturalRequest(.resolveModeConflict(
            draft: draft,
            currentLocation: locationModel.coordinate,
            mode: mode,
            keeping: keeping
        ))
    }

    func confirmNaturalCurrentLocation(draft: NaturalJourneyDraft) {
        guard let coordinate = locationModel.coordinate else { return }
        naturalCorrectionCount += 1
        performNaturalRequest(.confirmCurrentLocation(
            draft: draft,
            currentLocation: coordinate
        ))
    }

    func resolveNaturalTimeConflict(
        draft: NaturalJourneyDraft,
        keeping constraint: RouteTimeConstraint
    ) {
        naturalCorrectionCount += 1
        performNaturalRequest(.resolveTimeConflict(
            draft: draft,
            currentLocation: locationModel.coordinate,
            keeping: constraint
        ))
    }

    func continueNaturalSearchWithoutUnsupportedConstraints(draft: NaturalJourneyDraft) {
        naturalCorrectionCount += 1
        performNaturalRequest(.continueWithoutUnsupportedConstraints(
            draft: draft,
            currentLocation: locationModel.coordinate
        ))
    }

    func modifyNaturalQuery() {
        lastNaturalJourneyRequest = nil
        naturalSearchState = .input
    }

    func useClassicSearch() {
        naturalJourneyTask?.cancel()
        naturalJourneyCriteria = nil
        naturalQuery = ""
        lastNaturalJourneyRequest = nil
        naturalSearchState = .input
        isNaturalSearchPresented = false
        editDestination()
        clearQuery()
    }

    private func performNaturalRequest(_ request: NaturalJourneyRequest) {
        guard let naturalJourneyRepository else { return }
        lastNaturalJourneyRequest = request
        naturalJourneyTask?.cancel()
        naturalSearchState = .loading
        isNaturalSearchPresented = true
        naturalJourneyTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await naturalJourneyRepository.submit(request)
                guard !Task.isCancelled else { return }
                receiveNaturalJourneyResult(result)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                recordNaturalMetric(.failure)
                naturalSearchState = .failed(message: Self.naturalSearchErrorMessage(error))
            }
        }
    }

    private func receiveNaturalJourneyResult(_ result: NaturalJourneyResult) {
        switch result {
        case let .ready(interpretation, journeys):
            recordNaturalMetric(.success)
            naturalJourneyCriteria = NaturalJourneyCriteria(interpretation)
            selectedDestination = interpretation.destinationResult
            selectedDeparture = interpretation.originResult.map(SearchDepartureSelection.manual)
                ?? .currentLocation
            query = interpretation.destinationResult.name
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
            naturalSearchState = .input
            isNaturalSearchPresented = false
            naturalQuery = ""
            lastNaturalJourneyRequest = nil
        case let .needsClarification(draft, fields):
            recordNaturalMetric(.clarification)
            guard let field = fields.first else {
                naturalSearchState = .failed(message: "La demande doit être précisée.")
                return
            }
            naturalSearchState = .clarification(draft: draft, field: field)
        case let .needsDecision(draft, decision):
            recordNaturalMetric(.clarification)
            naturalSearchState = .decision(draft: draft, decision: decision)
        case let .networkUnavailable(interpretation):
            recordNaturalMetric(.failure)
            naturalJourneyCriteria = NaturalJourneyCriteria(interpretation)
            selectedDestination = interpretation.destinationResult
            selectedDeparture = interpretation.originResult.map(SearchDepartureSelection.manual)
                ?? .currentLocation
            query = interpretation.destinationResult.name
            naturalSearchState = .failed(
                message: "Connexion nécessaire pour rechercher les horaires."
            )
        case let .unsupported(message, examples):
            recordNaturalMetric(.unsupported)
            naturalSearchState = .unsupported(message: message, examples: examples)
        case let .unavailable(message, guidance):
            recordNaturalMetric(.unavailable)
            if let guidance {
                naturalSearchState = .availability(guidance)
            } else {
                naturalSearchState = .failed(message: message)
            }
        }
    }

    private static func naturalSearchErrorMessage(_ error: any Error) -> String {
        if error is NaturalIntentParsingError {
            return "Apple Intelligence n’a pas pu comprendre cette demande."
        }
        return "Connexion nécessaire pour rechercher les horaires."
    }

    private func recordNaturalMetric(_ outcome: NaturalJourneyMetric.Outcome) {
        guard let naturalSearchStartedAt else { return }
        let duration = max(0, metricsNow().timeIntervalSince(naturalSearchStartedAt))
        naturalJourneyMetrics.record(NaturalJourneyMetric(
            outcome: outcome,
            durationMilliseconds: Int(duration * 1000),
            correctionCount: naturalCorrectionCount
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
            await self.performSearch(normalized)
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
            await self.performSearch(normalized)

            guard !Task.isCancelled,
                  self.loadState == .loaded,
                  let firstResult = self.results.first else { return }
            self.selectDestination(firstResult)
        }
    }

    func retry() {
        let retryQuery = lastSearchedQuery.isEmpty
            ? query.trimmingCharacters(in: .whitespacesAndNewlines)
            : lastSearchedQuery

        guard retryQuery.count >= 2, step == .destination else { return }
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard !Task.isCancelled, let self else { return }
            await self.performSearch(retryQuery)
        }
    }

    func clearQuery() {
        updateQuery("")
    }

    func selectDestination(_ result: SearchResult) {
        searchTask?.cancel()
        account?.recordRecentSearch(result)
        selectedDestination = result
        results = []
        loadState = .idle
        planJourney()
    }

    func editDestination() {
        searchTask?.cancel()
        journeyTask?.cancel()
        let editingQuery = query.isEmpty
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
        preferred: Set<TransitMode>
    ) {
        guard required.isDisjoint(with: excluded),
              required.isDisjoint(with: preferred),
              excluded.isDisjoint(with: preferred),
              var criteria = naturalJourneyCriteria else { return }
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
        try await repository.search(query: query, near: locationModel.coordinate)
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

            guard let origin = await self.resolveOrigin() else {
                guard !Task.isCancelled else { return }
                self.step = .locationBlocked(self.locationModel.authorization)
                return
            }

            guard !Task.isCancelled else { return }

            var request = JourneyRequest(
                origin: origin,
                destination: JourneyPlaceSelection(selectedDestination).journeyDestination
            )
            request.limit = 4
            if var criteria = naturalJourneyCriteria {
                criteria.originCoordinate = origin
                criteria.originLabel = selectedDeparture.title
                if case let .manual(result) = selectedDeparture {
                    criteria.originResult = result
                } else {
                    criteria.originResult = nil
                }
                criteria.destinationResult = selectedDestination
                naturalJourneyCriteria = criteria
                request.requestedAt = criteria.requestedAt
                request.datetimeRepresents = criteria.datetimeRepresents
                request.requiredModes = criteria.requiredModes
                request.excludedModes = criteria.excludedModes
                request.preferredModes = criteria.preferredModes
            }

            do {
                let result = try await self.journeyRepository.plan(request)
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
            return await locationModel.requestCurrentLocation()
        case .saved, .manual:
            return selectedDeparture.coordinate
        }
    }

    private func performSearch(_ normalizedQuery: String) async {
        loadState = .loading
        lastSearchedQuery = normalizedQuery

        do {
            let response = try await repository.search(
                query: normalizedQuery,
                near: locationModel.coordinate
            )
            guard !Task.isCancelled else { return }

            results = response.results
            loadState = response.results.isEmpty ? .empty : .loaded
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            loadState = .failed(error.via)
        }
    }
}

private extension SearchResult {
    var departureSearchSubtitle: String? {
        switch self {
        case let .station(station):
            guard !station.routes.isEmpty else { return "Station" }
            return station.routes
                .prefix(3)
                .map(\.shortName)
                .joined(separator: " · ")
        case let .address(address):
            return address.context.isEmpty ? "Adresse" : address.context
        }
    }
}
