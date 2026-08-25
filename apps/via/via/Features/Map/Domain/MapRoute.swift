import Foundation

/// The routes a notification, shortcut or universal link can ask the map to
/// present. Parsing lives beside the route values so the shell only performs
/// UI work and every entry point shares the same validation rules.
enum MapRoute: Hashable, Sendable {
    case notifications
    case line(RouteID)
    case station(StationID)
    case activeJourney(JourneyID)
    case scheduledJourney(JourneyID)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "via", let host = url.host?.lowercased() else {
            return nil
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) -> String? in
            queryItems.first(where: { $0.name == name })?.value
        }

        switch host {
        case "notifications":
            self = .notifications
        case "line":
            guard let routeID = value("routeId"), !routeID.isEmpty else { return nil }
            self = .line(RouteID(rawValue: routeID))
        case "station":
            guard let stationID = value("stationId"), !stationID.isEmpty else { return nil }
            self = .station(StationID(rawValue: stationID))
        case "journey":
            let pathJourneyID = url.pathComponents
                .first(where: { $0 != "/" && !$0.isEmpty })
            guard let journeyID = value("journeyId") ?? pathJourneyID,
                  !journeyID.isEmpty
            else { return nil }

            switch value("mode")?.lowercased() {
            case "reminder":
                self = .scheduledJourney(JourneyID(rawValue: journeyID))
            case "active":
                self = .activeJourney(JourneyID(rawValue: journeyID))
            default:
                return nil
            }
        default:
            return nil
        }
    }
}
