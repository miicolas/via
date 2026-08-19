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
            result.departureSearchSubtitle
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

    var query = ""

    @ObservationIgnored private let repository: any SearchRepository
    @ObservationIgnored private let journeyRepository: any JourneyRepository
    @ObservationIgnored private let locationModel: LocationModel
    @ObservationIgnored private let account: AccountModel?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var journeyTask: Task<Void, Never>?
    @ObservationIgnored private var lastSearchedQuery = ""

    init(
        repository: any SearchRepository,
        journeyRepository: any JourneyRepository,
        locationModel: LocationModel,
        account: AccountModel? = nil
    ) {
        self.repository = repository
        self.journeyRepository = journeyRepository
        self.locationModel = locationModel
        self.account = account
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

    func selectJourney(_ journey: Journey) {
        guard journeyResult?.journeys.contains(where: { $0.id == journey.id }) == true else {
            return
        }
        mapPresentation = JourneyMapPresentation(journey: journey)
    }

    func searchPlaces(query: String) async throws -> SearchResponse {
        try await repository.search(query: query, near: locationModel.coordinate)
    }

    private func planJourney() {
        guard let selectedDestination else { return }

        journeyTask?.cancel()
        journeyResult = nil
        mapPresentation = nil
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
        case .station(let station):
            guard !station.routes.isEmpty else { return "Station" }
            return station.routes
                .prefix(3)
                .map(\.shortName)
                .joined(separator: " · ")
        case .address(let address):
            return address.context.isEmpty ? "Adresse" : address.context
        }
    }
}
