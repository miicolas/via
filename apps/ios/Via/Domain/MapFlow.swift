import Foundation

enum FlowScreen: String, Codable, Hashable, Sendable {
    case overview
    case search
    case planning
    case clarification
    case results
    case detail
}

struct MapFlowState: Equatable, Sendable {
    var screen: FlowScreen = .overview
    var searchFocused = false
    var hasSearchQuery = false
    var selectedStationID: String?
    var selectedJourneyIndex: Int?
    var overviewDetentIndex = 1
}

enum MapFlowEvent: Equatable, Sendable {
    case searchFocusChanged(Bool)
    case queryChanged(hasText: Bool)
    case stationSelected(id: String)
    case stationDeselected
    case detentChanged(Int)
    case journeyPlanningStarted
    case journeyResultsReady
    case journeyDetailOpened(index: Int)
    case journeyDetailClosed
    case journeyCancelled
    case naturalJourneySubmitted
    case naturalJourneyNeedsClarification
    case naturalJourneyReady
    case naturalJourneyFailed
    case naturalJourneyCancelled
}

@discardableResult
func transitionMapFlow(
    _ state: MapFlowState,
    event: MapFlowEvent
) -> MapFlowState {
    var next = state

    switch event {
    case .searchFocusChanged(let focused):
        next.searchFocused = focused
        next.screen = focused || state.hasSearchQuery
            ? .search
            : .overview
        if !focused && !state.hasSearchQuery {
            next.overviewDetentIndex = 1
        }

    case .queryChanged(let hasText):
        next.hasSearchQuery = hasText
        next.selectedStationID = nil
        next.selectedJourneyIndex = nil
        next.screen = !hasText && !state.searchFocused
            ? .overview
            : .search

    case .stationSelected(let id):
        next.selectedStationID = id
        next.selectedJourneyIndex = nil
        next.searchFocused = false
        next.screen = .overview
        next.overviewDetentIndex = 2

    case .stationDeselected:
        next.selectedStationID = nil
        next.selectedJourneyIndex = nil
        next.searchFocused = false
        next.hasSearchQuery = false
        next.screen = .overview
        next.overviewDetentIndex = 1

    case .detentChanged(let index):
        next.overviewDetentIndex = max(0, index)

    case .journeyPlanningStarted:
        next.screen = .planning
        next.selectedJourneyIndex = nil

    case .journeyResultsReady:
        next.screen = .results
        next.selectedJourneyIndex = nil

    case .journeyDetailOpened(let index):
        next.screen = .detail
        next.selectedJourneyIndex = max(0, index)

    case .journeyDetailClosed:
        next.screen = .results
        next.selectedJourneyIndex = nil

    case .journeyCancelled:
        next.screen = .overview
        next.selectedJourneyIndex = nil

    case .naturalJourneySubmitted:
        next.screen = .planning
        next.selectedJourneyIndex = nil

    case .naturalJourneyNeedsClarification, .naturalJourneyFailed:
        next.screen = .clarification
        next.selectedJourneyIndex = nil

    case .naturalJourneyReady:
        next.screen = .results
        next.selectedJourneyIndex = nil

    case .naturalJourneyCancelled:
        next.screen = .overview
        next.selectedJourneyIndex = nil
    }

    return next
}
