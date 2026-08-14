import Foundation
import Observation

enum AppRoute: Hashable, Codable, Sendable {
    case station(id: String)
    case line(id: String)
    case chat
}

enum AppDeepLink {
    static func route(for url: URL) -> AppRoute? {
        guard url.scheme?.lowercased() == "via" else { return nil }

        let pathSegments = url.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .compactMap { decode(String($0)) }
        let host = url.host.flatMap(decode)
        let segments = host.map { [$0] + pathSegments } ?? pathSegments

        guard let rawKind = segments.first else { return nil }
        let kind = rawKind.lowercased()
        let pathIdentifiers = Array(segments.dropFirst())
        guard pathIdentifiers.count <= 1 else { return nil }

        let queryIdentifier = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "id" })?
            .value
            .flatMap(decode)
        let identifier = pathIdentifiers.first ?? queryIdentifier

        switch kind {
        case "station":
            guard let identifier = validIdentifier(identifier) else { return nil }
            return .station(id: identifier)
        case "line":
            guard let identifier = validIdentifier(identifier) else { return nil }
            return .line(id: identifier)
        case "chat":
            guard pathIdentifiers.isEmpty, queryIdentifier == nil else { return nil }
            return .chat
        default:
            return nil
        }
    }

    private static func decode(_ value: String) -> String? {
        value.removingPercentEncoding
    }

    private static func validIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = []

    func handle(_ url: URL) {
        guard let route = AppDeepLink.route(for: url) else { return }
        open(route)
    }

    func open(_ route: AppRoute) {
        path = [route]
    }

    func consume(_ route: AppRoute) {
        guard path.last == route else { return }
        path.removeLast()
    }
}
