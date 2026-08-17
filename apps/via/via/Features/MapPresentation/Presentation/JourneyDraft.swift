import Foundation

struct JourneyDraft: Sendable, Equatable {
    var origin: JourneyPlaceSelection?
    var destination: JourneyPlaceSelection?
    var originQuery = ""
    var destinationQuery = ""

    func query(for field: MapPlaceField) -> String {
        switch field {
        case .origin: originQuery
        case .destination: destinationQuery
        }
    }

    mutating func setQuery(_ query: String, for field: MapPlaceField) {
        switch field {
        case .origin: originQuery = query
        case .destination: destinationQuery = query
        }
    }

    mutating func setPlace(_ place: JourneyPlaceSelection?, for field: MapPlaceField) {
        switch field {
        case .origin:
            origin = place
            originQuery = place?.name ?? ""
        case .destination:
            destination = place
            destinationQuery = place?.name ?? ""
        }
    }
}
