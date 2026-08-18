import Foundation

extension SearchResult {
    static let previewStation: SearchResult = {
        let area = StationsArea.mapPreview
        let station = area.stations.first { $0.id == StationID(rawValue: "preview:chatelet") }!
        let routes = station.routeIDs.compactMap { routeID in
            area.routes.first { $0.id == routeID }
        }

        return .station(StationSearchResult(
            id: station.id,
            name: station.name,
            coordinate: station.coordinate,
            routes: routes,
            distanceMeters: 240
        ))
    }()

    static let previewAddress: SearchResult = .address(AddressSearchResult(
        id: "preview:address:rivoli",
        name: "12 rue de Rivoli",
        context: "Paris",
        coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
        distanceMeters: 480
    ))
}

extension SearchResponse {
    static let preview = SearchResponse(
        results: [.previewStation, .previewAddress],
        addressSource: .ok
    )
}

extension InMemorySearchRepository {
    static let preview = InMemorySearchRepository(response: .preview)
}
