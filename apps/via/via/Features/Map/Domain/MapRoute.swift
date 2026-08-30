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

    static func meetupURL(token: String, key: String? = nil) -> URL {
        let invitation = base.appending(path: "meet").appending(path: token)
        guard let key else { return invitation }
        var components = URLComponents(url: invitation, resolvingAgainstBaseURL: false)
        components?.fragment = "k=\(key)"
        return components?.url ?? invitation
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
    case meetup(String)
    case meetupInvitation(token: String, key: String?)
    case friendInvitation(String)

    init?(url: URL) {
        guard let scheme = url.scheme?.lowercased() else { return nil }

        if scheme == "https" {
            guard
                let host = url.host?.lowercased(),
                ShareLinkOrigin.isKnownHost(host)
            else { return nil }

            let components = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            if components.count == 3,
               components[0].lowercased() == "meet",
               components[1].lowercased() == "friend",
               let token = Self.capabilityToken(from: components[2]) {
                self = .friendInvitation(token)
                return
            }
            guard components.count == 2, let rawToken = components.last else { return nil }
            switch components[0].lowercased() {
            case "trip":
                guard let token = Self.shareToken(from: rawToken) else { return nil }
                self = .sharedJourney(token)
                return
            case "meet":
                guard let token = Self.capabilityToken(from: rawToken),
                      let key = Self.meetupFragmentKey(from: url)
                else { return nil }
                self = .meetupInvitation(token: token, key: key)
                return
            default:
                return nil
            }
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
            let rawToken = url.pathComponents
                .first(where: { $0 != "/" && !$0.isEmpty })
            guard
                let rawToken,
                let token = Self.shareToken(from: rawToken)
            else { return nil }
            self = .sharedJourney(token)
        case "meet":
            let rawToken = url.pathComponents
                .first(where: { $0 != "/" && !$0.isEmpty })
            guard let rawToken,
                  let token = Self.capabilityToken(from: rawToken),
                  let key = Self.meetupFragmentKey(from: url)
            else { return nil }
            self = .meetupInvitation(token: token, key: key)
        case "meetup":
            let meetupID = url.pathComponents
                .first(where: { $0 != "/" && !$0.isEmpty })
            guard let meetupID, UUID(uuidString: meetupID) != nil else { return nil }
            self = .meetup(meetupID.lowercased())
        case "friend":
            let rawToken = url.pathComponents
                .first(where: { $0 != "/" && !$0.isEmpty })
            guard let rawToken, let token = Self.capabilityToken(from: rawToken) else { return nil }
            self = .friendInvitation(token)
        case "journey":
            if value("mode")?.lowercased() == "shared",
               let rawToken = value("token"),
               let token = Self.shareToken(from: rawToken) {
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

    private static let legacyShareMessage = " Voici un trajet partagé dans Metyro."

    /// ShareLink's former optional message was appended to the URL by some
    /// activities. Decode the two forms observed at the web boundary and only
    /// recover the token when the complete historical suffix matches.
    private static func shareToken(from value: String) -> String? {
        var candidate = value

        for pass in 0...2 {
            if isValidShareToken(candidate) { return candidate }

            if candidate.hasSuffix(legacyShareMessage) {
                let token = String(candidate.dropLast(legacyShareMessage.count))
                if isValidShareToken(token) { return token }
            }

            guard
                pass < 2,
                let decoded = candidate.removingPercentEncoding,
                decoded != candidate
            else { break }
            candidate = decoded
        }

        return nil
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

    private static func capabilityToken(from value: String) -> String? {
        guard isValidShareToken(value) else { return nil }
        return value
    }

    /// A missing fragment means no precise-position key was shared. Once a
    /// fragment exists it must be the one supported shape; silently dropping a
    /// malformed key would make a privacy failure look like a valid invite.
    private static func meetupFragmentKey(from url: URL) -> String?? {
        guard let fragment = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.fragment else { return .some(nil) }
        guard fragment.hasPrefix("k=") else { return nil }
        let value = String(fragment.dropFirst(2))
        guard isValidShareToken(value) else { return nil }
        return .some(value)
    }
}
