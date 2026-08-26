import Foundation

/// Where a shared trip lives on the web.
///
/// The app has already been renamed once. This origin is read by the parser
/// that decides whether an incoming universal link is ours, by the sheet that
/// shows the recipient a link, and by the preview fixtures — and a mismatch
/// between them does not fail to build, it ships a link the app then refuses to
/// open. The server keeps the same value in `VIA_SITE_URL`.
enum ShareLinkOrigin {
    static let host = "metyro.app"

    /// The one force-unwrap, over a literal that cannot fail to parse, so that
    /// no caller has to write its own.
    static let base = URL(string: "https://\(host)")!

    static func url(token: String) -> URL {
        base.appending(path: "trip").appending(path: token)
    }

    static func isKnownHost(_ candidate: String) -> Bool {
        candidate == host || candidate == "www.\(host)"
    }
}

/// The routes a notification, shortcut or universal link can ask the map to
/// present. Parsing lives beside the route values so the shell only performs
/// UI work and every entry point shares the same validation rules.
enum MapRoute: Hashable, Sendable {
    case notifications
    case line(RouteID)
    case station(StationID)
    case activeJourney(JourneyID)
    case scheduledJourney(JourneyID)
    case sharedJourney(String)

    init?(url: URL) {
        guard let scheme = url.scheme?.lowercased() else { return nil }

        if scheme == "https" {
            guard
                let host = url.host?.lowercased(),
                ShareLinkOrigin.isKnownHost(host)
            else { return nil }

            let components = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            guard
                components.count == 2,
                components[0].lowercased() == "trip",
                let token = components.last,
                Self.isValidShareToken(token)
            else { return nil }

            self = .sharedJourney(token)
            return
        }

        guard scheme == "via", let host = url.host?.lowercased() else {
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
        case "trip":
            let pathToken = url.pathComponents
                .first(where: { $0 != "/" && !$0.isEmpty })
            guard let token = pathToken, Self.isValidShareToken(token) else { return nil }
            self = .sharedJourney(token)
        case "journey":
            if value("mode")?.lowercased() == "shared",
               let token = value("token"),
               Self.isValidShareToken(token) {
                self = .sharedJourney(token)
                return
            }

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

    private static func isValidShareToken(_ token: String) -> Bool {
        guard token.utf8.count == 43 else { return false }
        return token.utf8.allSatisfy { byte in
            (65...90).contains(byte)
                || (97...122).contains(byte)
                || (48...57).contains(byte)
                || byte == 45
                || byte == 95
        }
    }
}
