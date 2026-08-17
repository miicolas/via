import Foundation

enum PlaceSearchState: Sendable, Equatable {
    case idle
    case debouncing(previous: SearchResponse?)
    case loading(previous: SearchResponse?)
    case loaded(SearchResponse)
    case empty(addressSource: SearchResponse.AddressSource)
    case failed(ViaError, previous: SearchResponse?)

    var visibleResponse: SearchResponse? {
        switch self {
        case .loaded(let response):
            response
        case .debouncing(let previous),
             .loading(let previous),
             .failed(_, let previous):
            previous
        case .idle, .empty:
            nil
        }
    }

    var isLoading: Bool {
        switch self {
        case .debouncing, .loading: true
        default: false
        }
    }
}
