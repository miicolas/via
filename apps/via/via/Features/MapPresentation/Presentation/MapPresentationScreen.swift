enum MapPresentationScreen: Equatable {
    case planner(MapPlannerStage)
    case station(StationMapItem)

    var station: StationMapItem? {
        guard case .station(let station) = self else { return nil }
        return station
    }
}

enum MapPlannerStage: Equatable {
    case editing(MapPlaceField?)
    case planning
    case results
}

enum MapPlaceField: Sendable, Hashable {
    case origin
    case destination
}

enum MapPresentationSheetRoute: String, Equatable, Identifiable {
    case journeys

    var id: String { rawValue }
}
