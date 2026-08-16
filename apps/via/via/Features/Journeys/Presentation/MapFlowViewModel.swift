import Foundation
import Observation

enum MapFlowState: Sendable, Equatable {
    case map
    case search
    case planning(destination: SearchResult)
    case results(request: JourneyRequest, result: JourneyResult)
    case detail(request: JourneyRequest, result: JourneyResult, journeyID: JourneyID)
}

enum MapFlowEvent: Sendable, Equatable {
    case openSearch
    case closeSearch
    case selectDestination(SearchResult)
    case receiveResults(request: JourneyRequest, result: JourneyResult)
    case selectJourney(JourneyID)
    case closeDetail
    case reset
}

@MainActor
@Observable
final class MapFlowViewModel {
    private(set) var state: MapFlowState = .map

    func send(_ event: MapFlowEvent) {
        state = Self.reduce(state: state, event: event)
    }

    private static func reduce(state: MapFlowState, event: MapFlowEvent) -> MapFlowState {
        switch (state, event) {
        case (_, .reset): .map
        case (.map, .openSearch): .search
        case (.search, .closeSearch): .map
        case (.search, .selectDestination(let destination)): .planning(destination: destination)
        case (.planning, .receiveResults(let request, let result)): .results(request: request, result: result)
        case (.results(let request, let result), .selectJourney(let id)): .detail(request: request, result: result, journeyID: id)
        case (.detail(let request, let result, _), .closeDetail): .results(request: request, result: result)
        default: state
        }
    }
}

