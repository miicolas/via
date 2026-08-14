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
    var searchQuery = ""
    var selectedStationID: String?
    var overviewDetentIndex = 1
}

enum MapFlowEvent: Equatable, Sendable {
    case searchFocusChanged(Bool)
    case queryChanged(String)
    case stationSelected(id: String, query: String?)
    case stationDeselected
    case detentChanged(Int)
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
        next.screen = focused || !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .search
            : .overview
        if !focused && state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next.overviewDetentIndex = 1
        }

    case .queryChanged(let query):
        next.searchQuery = query
        next.selectedStationID = nil
        next.screen = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !state.searchFocused
            ? .overview
            : .search

    case .stationSelected(let id, let query):
        next.selectedStationID = id
        next.searchFocused = false
        if let query { next.searchQuery = query }
        next.screen = .overview
        next.overviewDetentIndex = 2

    case .stationDeselected:
        next.selectedStationID = nil
        next.searchFocused = false
        next.searchQuery = ""
        next.screen = .overview
        next.overviewDetentIndex = 1

    case .detentChanged(let index):
        next.overviewDetentIndex = max(0, index)
    }

    return next
}
