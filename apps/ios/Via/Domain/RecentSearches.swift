import Foundation

enum RecentSearchStorage {
    static let key = "via.recent-searches.v1"
    static let version = 1
    static let maximumCount = 5
}

func recentSearchKey(_ result: SearchResult) -> String {
    switch result {
    case .station(let station): "station:\(station.id)"
    case .address(let address): "address:\(address.id)"
    }
}

func recentSearchSnapshot(_ result: SearchResult) -> SearchResult {
    switch result {
    case .station(let station):
        .station(
            StationSearchResult(
                id: station.id,
                name: station.name,
                coordinate: station.coordinate,
                routes: station.routes,
                distanceMeters: nil
            )
        )
    case .address(let address):
        .address(
            AddressSearchResult(
                id: address.id,
                name: address.name,
                context: address.context,
                coordinate: address.coordinate,
                distanceMeters: nil
            )
        )
    }
}

func rememberRecentSearches(_ entries: [SearchResult], result: SearchResult) -> [SearchResult] {
    let snapshot = recentSearchSnapshot(result)
    let key = recentSearchKey(snapshot)
    return Array(
        ([snapshot] + entries.filter { recentSearchKey($0) != key }.map(recentSearchSnapshot))
            .prefix(RecentSearchStorage.maximumCount)
    )
}

func serializeRecentSearches(_ entries: [SearchResult]) -> Data? {
    try? JSONEncoder().encode(
        RecentSearchStoragePayload(
            version: RecentSearchStorage.version,
            entries: Array(entries.map(recentSearchSnapshot).prefix(RecentSearchStorage.maximumCount))
        )
    )
}

func parseRecentSearches(_ data: Data?) -> [SearchResult] {
    guard let data else { return [] }

    do {
        let payload = try JSONDecoder().decode(RecentSearchStoragePayload.self, from: data)
        guard payload.version == RecentSearchStorage.version else { return [] }

        var seen = Set<String>()
        return Array(
            payload.entries
                .map(recentSearchSnapshot)
                .filter { result in
                    guard isValidRecentSearch(result) else { return false }
                    return seen.insert(recentSearchKey(result)).inserted
                }
                .prefix(RecentSearchStorage.maximumCount)
        )
    } catch {
        return []
    }
}

private struct RecentSearchStoragePayload: Codable {
    let version: Int
    let entries: [SearchResult]
}

private func isValidRecentSearch(_ result: SearchResult) -> Bool {
    let coordinate = result.coordinate
    guard coordinate.latitude.isFinite,
          (-90...90).contains(coordinate.latitude),
          coordinate.longitude.isFinite,
          (-180...180).contains(coordinate.longitude)
    else { return false }

    switch result {
    case .station(let station):
        return !station.id.isEmpty && !station.name.isEmpty
    case .address(let address):
        return !address.id.isEmpty && !address.name.isEmpty
    }
}
