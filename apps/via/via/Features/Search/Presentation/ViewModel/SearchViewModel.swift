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

struct SearchQuery: Sendable, Hashable {
    let destination: SearchResult
    let departure: SearchDepartureSelection
}

@MainActor
@Observable
final class SearchViewModel {
    private(set) var step: SearchViewStep = .destination
    private(set) var results: [SearchResult] = []
    private(set) var loadState: SearchLoadState = .idle
    private(set) var journeyResult: JourneyResult?
    private(set) var selectedDestination: SearchResult?
    private(set) var selectedDeparture: SearchDepartureSelection = .currentLocation

    var query = ""

    @ObservationIgnored private let repository: any SearchRepository
    @ObservationIgnored private let journeyRepository: any JourneyRepository
    @ObservationIgnored private let locationModel: LocationModel
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var journeyTask: Task<Void, Never>?
    @ObservationIgnored private var lastSearchedQuery = ""

    init(
        repository: any SearchRepository,
        journeyRepository: any JourneyRepository,
        locationModel: LocationModel
    ) {
        self.repository = repository
        self.journeyRepository = journeyRepository
        self.locationModel = locationModel
    }

    var subtitle: String {
        "Depuis \(selectedDeparture.title)"
    }

    var searchQuery: SearchQuery? {
        guard let selectedDestination else { return nil }
        return SearchQuery(
            destination: selectedDestination,
            departure: selectedDeparture
        )
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

    /// Kept as a small compatibility seam for callers that submit an already
    /// selected query. New UI submits from the destination result directly.
    @discardableResult
    func submitSearch() -> SearchQuery? {
        guard let searchQuery else { return nil }
        planJourney()
        return searchQuery
    }

    func editSubmittedSearch() {
        guard selectedDestination != nil else { return }
        editDestination()
    }

    private func planJourney() {
        guard let selectedDestination else { return }

        journeyTask?.cancel()
        journeyResult = nil
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
