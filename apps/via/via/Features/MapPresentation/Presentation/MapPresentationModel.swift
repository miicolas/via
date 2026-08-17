import Foundation
import Observation
import SwiftUI

enum MapPresentationEvent {
    case requestLocation
    case preparePlanner
    case openPlanner
    case focus(MapPlaceField)
    case queryChanged(MapPlaceField, String)
    case selectResult(SearchResult)
    case selectRecent(RecentSearch)
    case removeRecent(RecentSearch)
    case useCurrentLocation
    case clearRecents
    case swapPlaces
    case backToForm
    case newSearch
    case retrySearch
    case retryJourneys
    case selectMapStation(StationMapItem?)
    case closeStation
    case dismissSearch
    case closeJourneys
    case selectJourney(JourneyID)
    case detentChanged(PresentationDetent)
}

@MainActor
@Observable
final class MapPresentationModel {
    private(set) var state: MapPresentationState

    @ObservationIgnored private let searchRepository: any SearchRepository
    @ObservationIgnored private let journeyRepository: any JourneyRepository
    @ObservationIgnored private let account: AccountModel
    @ObservationIgnored private let locationAdapter: any LocationAdapter
    @ObservationIgnored private let searchDelay: Duration
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var journeyTask: Task<Void, Never>?
    @ObservationIgnored private var searchRevision = 0
    @ObservationIgnored private var journeyRevision = 0
    @ObservationIgnored private var currentLocation: GeoCoordinate?
    @ObservationIgnored private var hasRequestedLocation = false

    init(
        searchRepository: any SearchRepository,
        journeyRepository: any JourneyRepository,
        account: AccountModel,
        locationAdapter: any LocationAdapter,
        searchDelay: Duration = .milliseconds(600)
    ) {
        self.searchRepository = searchRepository
        self.journeyRepository = journeyRepository
        self.account = account
        self.locationAdapter = locationAdapter
        self.searchDelay = searchDelay
        state = MapPresentationState(authorization: locationAdapter.authorization)
        locationAdapter.onEvent = { [weak self] event in
            self?.receiveLocation(event)
        }
    }

    func send(_ event: MapPresentationEvent) {
        switch event {
        case .requestLocation:
            requestLocation(force: true)
        case .preparePlanner:
            preparePlanner()
        case .openPlanner:
            openPlanner()
        case .focus(let field):
            focus(field)
        case .queryChanged(let field, let query):
            updateQuery(query, for: field)
        case .selectResult(let result):
            select(JourneyPlaceSelection(result), recentResult: result)
        case .selectRecent(let recent):
            let result = recent.searchResult
            select(JourneyPlaceSelection(result), recentResult: result)
        case .removeRecent(let recent):
            removeRecentSearch(recent)
        case .useCurrentLocation:
            useCurrentLocation()
        case .clearRecents:
            account.clearRecentSearches()
        case .swapPlaces:
            swapPlaces()
        case .backToForm:
            cancelSearch()
            restoreJourneysAfterCancellation()
            state.screen = .planner(.editing(.destination))
            state.search = .idle
            state.selectedDetent = .large
        case .newSearch:
            newSearch()
        case .retrySearch:
            scheduleSearch(delay: .zero)
        case .retryJourneys:
            retryJourneys()
        case .selectMapStation(let station):
            selectMapStation(station)
        case .closeStation:
            showCompactPlanner()
        case .dismissSearch:
            dismissSearch()
        case .closeJourneys:
            closeJourneys()
        case .selectJourney(let id):
            state.selectedJourneyID = id
        case .detentChanged(let detent):
            selectDetent(detent)
        }
    }

    private func preparePlanner() {
        guard state.plannerStage == .editing(nil) else { return }
        state.search = .idle
        requestLocation()
    }

    private func openPlanner() {
        state.search = .idle
        switch state.plannerStage {
        case .some(.planning), .some(.results):
            state.selectedDetent = MapPresentationState.searchDetent
        case .some(.editing(nil)), nil:
            state.screen = .planner(.editing(.destination))
            state.selectedDetent = .large
        case .some(.editing):
            state.selectedDetent = .large
        }
        requestLocation()
    }

    private func focus(_ field: MapPlaceField) {
        cancelSearch()
        restoreJourneysAfterCancellation()
        state.screen = .planner(.editing(field))
        state.search = .idle
        state.selectedDetent = .large
        requestLocation()
    }

    private func updateQuery(_ query: String, for field: MapPlaceField) {
        state.screen = .planner(.editing(field))
        let selectedPlace = field == .origin ? state.draft.origin : state.draft.destination
        guard selectedPlace?.name != query else { return }
        state.draft.setPlace(nil, for: field)
        state.draft.setQuery(query, for: field)
        scheduleSearch()
    }

    private func select(
        _ place: JourneyPlaceSelection,
        recentResult: SearchResult
    ) {
        let field: MapPlaceField
        if let activeField = state.activeField {
            field = activeField
        } else if state.plannerStage == .editing(nil) {
            field = .destination
        } else {
            return
        }

        cancelSearch()
        state.draft.setPlace(place, for: field)

        switch field {
        case .origin:
            state.search = .idle
            state.screen = .planner(.editing(.destination))
        case .destination:
            account.recordRecentSearch(recentResult)
            state.search = .idle
            if state.draft.origin == nil, case .located(let coordinate) = state.location {
                state.draft.setPlace(.currentLocation(coordinate), for: .origin)
            }
            if state.draft.origin == nil {
                state.screen = .planner(.editing(.destination))
                state.selectedDetent = .large
                requestLocation()
            } else {
                planCurrentDraft()
            }
        }
    }

    private func swapPlaces() {
        guard let origin = state.draft.origin,
              let destination = state.draft.destination else { return }
        state.draft.setPlace(destination, for: .origin)
        state.draft.setPlace(origin, for: .destination)
        planCurrentDraft()
    }

    private func useCurrentLocation() {
        guard case .located(let coordinate) = state.location else { return }
        cancelSearch()
        state.draft.setPlace(.currentLocation(coordinate), for: .origin)
        state.search = .idle
        state.screen = .planner(.editing(.destination))
    }

    private func removeRecentSearch(_ recent: RecentSearch) {
        account.removeRecentSearch(id: recent.id)
    }

    private func newSearch() {
        clearJourneys()
        state.screen = .planner(.editing(.destination))
        state.selectedDetent = .large
        requestLocation()
    }

    private func closeJourneys() {
        guard state.plannerStage == .planning || state.plannerStage == .results else {
            return
        }
        clearJourneys()
        state.screen = .planner(.editing(nil))
        state.selectedDetent = MapPresentationState.collapsedDetent
    }

    private func clearJourneys() {
        cancelSearch()
        cancelJourney()
        state.draft.setPlace(nil, for: .destination)
        state.journeys = .idle
        state.currentRequest = nil
        state.displayedRequest = nil
        state.selectedJourneyID = nil
        state.search = .idle
    }

    private func selectMapStation(_ station: StationMapItem?) {
        if case .station = state.screen {
            if station == nil { showCompactPlanner() }
            return
        }
        guard state.stationSelectionEnabled, let station else { return }
        state.screen = .station(station)
        state.selectedDetent = .medium
    }

    private func dismissSearch() {
        cancelSearch()
        restoreJourneysAfterCancellation()
        state.search = .idle
        if state.journeyResult != nil {
            state.screen = .planner(.results)
            state.selectedDetent = MapPresentationState.collapsedDetent
        } else {
            state.screen = .planner(.editing(nil))
            state.selectedDetent = MapPresentationState.collapsedDetent
        }
    }

    private func showCompactPlanner() {
        state.screen = .planner(state.journeyResult == nil ? .editing(nil) : .results)
        state.selectedDetent = MapPresentationState.collapsedDetent
    }

    private func selectDetent(_ detent: PresentationDetent) {
        state.selectedDetent = detent
        if case .station = state.screen,
           detent == MapPresentationState.collapsedDetent {
            showCompactPlanner()
        }
    }

    private func scheduleSearch(delay: Duration? = nil) {
        cancelSearch()
        let query = state.activeField.map { state.draft.query(for: $0) } ?? ""
        let sanitized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            state.search = .idle
            return
        }

        let revision = searchRevision
        let previous = state.search.visibleResponse
        let anchor = currentLocation ?? state.draft.origin?.coordinate
        state.search = .debouncing(previous: previous)
        searchTask = Task { [weak self, searchRepository] in
            guard let self else { return }
            do {
                try await Task.sleep(for: delay ?? searchDelay)
                guard revision == searchRevision else { return }
                state.search = .loading(previous: previous)
                let response = try await searchRepository.search(
                    query: sanitized,
                    near: anchor
                )
                try Task.checkCancellation()
                guard revision == searchRevision else { return }
                state.search = response.results.isEmpty
                    ? .empty(addressSource: response.addressSource)
                    : .loaded(response)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, revision == searchRevision else { return }
                state.search = .failed(error.via, previous: previous)
            }
        }
    }

    private func cancelSearch() {
        searchRevision &+= 1
        searchTask?.cancel()
        searchTask = nil
    }

    private func planCurrentDraft() {
        guard let origin = state.draft.origin,
              let destination = state.draft.destination else { return }
        cancelJourney()
        let request = JourneyRequest(
            origin: origin.coordinate,
            destination: destination.journeyDestination,
            limit: 4
        )
        let revision = journeyRevision
        let previous = state.journeys.value
        state.currentRequest = request
        state.journeys = .loading(previous: previous)
        state.screen = .planner(.planning)
        state.selectedDetent = MapPresentationState.collapsedDetent

        journeyTask = Task { [weak self, journeyRepository] in
            guard let self else { return }
            do {
                let result = try await journeyRepository.plan(request)
                try Task.checkCancellation()
                guard revision == journeyRevision else { return }
                state.journeys = .loaded(result)
                state.displayedRequest = request
                state.selectedJourneyID = result.journeys.first?.id
                state.screen = .planner(.results)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, revision == journeyRevision else { return }
                state.journeys = .failed(error.via, previous: previous)
                state.screen = .planner(.results)
            }
        }
    }

    private func retryJourneys() {
        guard state.draft.origin != nil, state.draft.destination != nil else { return }
        planCurrentDraft()
    }

    private func cancelJourney() {
        journeyRevision &+= 1
        journeyTask?.cancel()
        journeyTask = nil
    }

    private func restoreJourneysAfterCancellation() {
        guard case .loading(let previous) = state.journeys else { return }
        cancelJourney()
        state.journeys = previous.map(Loadable.loaded) ?? .idle
        state.currentRequest = state.displayedRequest
    }

    private func requestLocation(force: Bool = false) {
        guard force || !hasRequestedLocation else { return }
        hasRequestedLocation = true
        switch locationAdapter.authorization {
        case .notDetermined:
            state.location = .idle(authorization: .notDetermined)
            locationAdapter.requestAuthorization()
        case .authorized:
            state.location = .locating
            locationAdapter.requestLocation()
        case .restricted, .denied:
            state.location = .failed(locationAdapter.authorization)
            requireManualOriginIfNeeded()
        }
    }

    private func receiveLocation(_ event: LocationAdapterEvent) {
        switch event {
        case .authorizationChanged(let authorization):
            state.location = .idle(authorization: authorization)
            if authorization == .authorized {
                state.location = .locating
                locationAdapter.requestLocation()
            } else if authorization == .restricted || authorization == .denied {
                state.location = .failed(authorization)
                requireManualOriginIfNeeded()
            }
        case .located(let coordinate):
            currentLocation = coordinate
            state.location = .located(coordinate)
            if state.draft.origin == nil || state.draft.origin?.isCurrentLocation == true {
                state.draft.setPlace(.currentLocation(coordinate), for: .origin)
            }
            if state.draft.destination != nil,
               state.draft.origin != nil,
               state.plannerStage != .planning,
               state.journeyResult == nil {
                planCurrentDraft()
            }
        case .failed(let authorization):
            state.location = .failed(authorization)
            requireManualOriginIfNeeded()
        }
    }

    private func requireManualOriginIfNeeded() {
        guard state.draft.origin == nil else { return }
        state.screen = .planner(.editing(.destination))
        state.selectedDetent = .large
        state.search = .idle
    }
}
