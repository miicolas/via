enum MapPresentationDestination: Equatable {
    case search
    case station(StationMapItem)

    var station: StationMapItem? {
        guard case .station(let station) = self else { return nil }
        return station
    }
}
