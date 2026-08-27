import Foundation

/// Reads the line conditions straight from the API, so a saved line that falls
/// over is on the Lock Screen without the traveller having opened the app.
///
/// Deliberately not the app's OpenAPI client: `/lines/statuses` is one
/// unauthenticated GET behind the first-party client key, and linking the whole
/// generated stack — plus its auth middleware and its session vault — into a
/// widget extension would cost far more than the twenty lines it replaces. What
/// it does share is the client key: the extension names itself to the API the
/// same way the app does, per ADR 0003.
struct WidgetLineStatusRemote: Sendable {
    /// Named once, matching the app's `APIClientKey.header`.
    private static let clientKeyHeader = "x-via-client-key"

    let baseURL: URL
    let clientKey: String?

    /// `nil` when the build has no API base URL — the widget then keeps drawing
    /// the snapshot the app published, which is the right answer rather than a
    /// blank tile.
    static func bundled(bundle: Bundle = .main) -> WidgetLineStatusRemote? {
        guard
            let rawValue = bundle.object(forInfoDictionaryKey: "VIA_API_BASE_URL") as? String,
            let url = URL(string: rawValue),
            url.host != nil
        else { return nil }

        let key = (bundle.object(forInfoDictionaryKey: "VIA_API_CLIENT_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return WidgetLineStatusRemote(
            baseURL: url,
            clientKey: key?.isEmpty == false ? key : nil
        )
    }

    /// The saved lines only. The board answers with the whole rail catalogue,
    /// and a widget has no use for the lines the traveller never saved.
    func statuses(for routeIDs: [String]) async throws -> [WidgetLineStatus] {
        guard !routeIDs.isEmpty else { return [] }

        var request = URLRequest(url: baseURL.appending(path: "lines/statuses"))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let clientKey {
            request.setValue(clientKey, forHTTPHeaderField: Self.clientKeyHeader)
        }
        // A widget refresh the system granted is not worth holding open: an
        // unreachable API has to fall back to the published snapshot quickly.
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            let http = response as? HTTPURLResponse,
            (200...299).contains(http.statusCode)
        else { throw WidgetLineStatusError.unavailable }

        let board = try JSONDecoder().decode(BoardResponse.self, from: data)
        guard board.source == "live" else { throw WidgetLineStatusError.unavailable }

        let wanted = Set(routeIDs)
        let byID = Dictionary(
            board.lines
                .filter { wanted.contains($0.route.id) }
                .map { ($0.route.id, $0.widgetStatus) },
            uniquingKeysWith: { first, _ in first }
        )

        // The traveller's own order is the one the app published; the widget
        // re-sorts by condition, never by what the API happened to return.
        return routeIDs.compactMap { byID[$0] }
    }
}

enum WidgetLineStatusError: Error, Sendable {
    case unavailable
}

private struct BoardResponse: Decodable {
    struct Line: Decodable {
        struct Route: Decodable {
            let id: String
            let shortName: String
            let mode: String
            let color: String
            let textColor: String
        }

        /// Presence is the whole signal; the start date is never drawn, so it
        /// stays an undecoded string rather than pulling a date strategy into
        /// the extension.
        struct Upcoming: Decodable {
            let beginsAt: String?
        }

        let route: Route
        let condition: String
        let summary: String?
        let upcoming: Upcoming?

        var widgetStatus: WidgetLineStatus {
            WidgetLineStatus(
                routeID: route.id,
                shortName: route.shortName,
                modeName: WidgetTransitModeName.french(forMode: route.mode),
                colorHex: route.color,
                textColorHex: route.textColor,
                condition: WidgetLineCondition(rawValue: condition) ?? .normal,
                summary: summary,
                hasUpcomingClosure: upcoming != nil
            )
        }
    }

    let source: String
    let lines: [Line]
}
