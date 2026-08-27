import WidgetKit

struct FavoriteLinesEntry: TimelineEntry {
    let date: Date
    /// The saved lines the widget draws, worst condition first.
    let lines: [WidgetLineStatus]
    /// Every saved line, before the "perturbées seulement" filter. What tells a
    /// filtered widget apart from an empty one: no line saved at all is an
    /// empty state, all of them running is good news.
    let savedLineCount: Int
    /// When the conditions were last read. `nil` when they never were.
    let refreshedAt: Date?

    init(
        date: Date,
        lines: [WidgetLineStatus],
        savedLineCount: Int,
        refreshedAt: Date?
    ) {
        self.date = date
        self.lines = lines
        self.savedLineCount = savedLineCount
        self.refreshedAt = refreshedAt
    }
}

struct FavoriteLinesProvider: AppIntentTimelineProvider {
    /// How long a drawn board stays on screen before the system is asked for
    /// another refresh. Widgets get a daily budget; twenty minutes keeps a
    /// disruption from sitting stale for an hour without spending the whole
    /// allowance before lunch.
    private static let refreshInterval: TimeInterval = 20 * 60

    func placeholder(in context: Context) -> FavoriteLinesEntry {
        FavoriteLinesEntry(
            date: .now,
            lines: Self.placeholderLines,
            savedLineCount: Self.placeholderLines.count,
            refreshedAt: .now
        )
    }

    func snapshot(
        for configuration: FavoriteLinesConfigurationIntent,
        in context: Context
    ) async -> FavoriteLinesEntry {
        await entry(for: configuration)
    }

    func timeline(
        for configuration: FavoriteLinesConfigurationIntent,
        in context: Context
    ) async -> Timeline<FavoriteLinesEntry> {
        let entry = await entry(for: configuration)
        return Timeline(
            entries: [entry],
            policy: .after(entry.date.addingTimeInterval(Self.refreshInterval))
        )
    }

    private func entry(
        for configuration: FavoriteLinesConfigurationIntent
    ) async -> FavoriteLinesEntry {
        let snapshot = WidgetFavoritesStore().read()
        let refreshed = await refreshedLines(for: snapshot)
        let lines = Self.ordered(refreshed?.lines ?? snapshot.lines)

        return FavoriteLinesEntry(
            date: .now,
            lines: configuration.disruptedOnly ? lines.filter(\.condition.isDisrupted) : lines,
            savedLineCount: lines.count,
            refreshedAt: refreshed?.at ?? snapshot.linesFetchedAt
        )
    }

    /// The live board, or `nil` when the API could not be reached — the widget
    /// then keeps drawing what the app last published, dated honestly, rather
    /// than emptying itself because a refresh failed.
    private func refreshedLines(
        for snapshot: WidgetFavoritesSnapshot
    ) async -> (lines: [WidgetLineStatus], at: Date)? {
        guard
            !snapshot.lines.isEmpty,
            let remote = WidgetLineStatusRemote.bundled()
        else { return nil }

        do {
            let fresh = try await remote.statuses(for: snapshot.lines.map(\.routeID))
            guard !fresh.isEmpty else { return nil }

            let byID = Dictionary(
                fresh.map { ($0.routeID, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            // A saved line the board does not carry — a bus, which the rail
            // catalogue omits — keeps what the app published rather than
            // disappearing from the widget until the next launch.
            return (snapshot.lines.map { byID[$0.routeID] ?? $0 }, .now)
        } catch {
            return nil
        }
    }

    /// Worst first, ties keeping the order the traveller saved them in.
    private static func ordered(_ lines: [WidgetLineStatus]) -> [WidgetLineStatus] {
        lines
            .enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.condition.displayPriority
                let right = rhs.element.condition.displayPriority
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }

    private static let placeholderLines = [
        WidgetLineStatus(
            routeID: "preview:rer:A",
            shortName: "A",
            modeName: "RER",
            colorHex: "#E3051C",
            textColorHex: "#FFFFFF",
            condition: .disrupted,
            summary: "Trafic perturbé entre Nation et Vincennes",
            hasUpcomingClosure: false
        ),
        WidgetLineStatus(
            routeID: "preview:metro:1",
            shortName: "1",
            modeName: "Métro",
            colorHex: "#FFCD00",
            textColorHex: "#000000",
            condition: .normal,
            summary: nil,
            hasUpcomingClosure: true
        ),
        WidgetLineStatus(
            routeID: "preview:metro:4",
            shortName: "4",
            modeName: "Métro",
            colorHex: "#BB4D98",
            textColorHex: "#FFFFFF",
            condition: .normal,
            summary: nil,
            hasUpcomingClosure: false
        ),
        WidgetLineStatus(
            routeID: "preview:tram:T3a",
            shortName: "T3a",
            modeName: "Tram",
            colorHex: "#FF7E2E",
            textColorHex: "#000000",
            condition: .normal,
            summary: nil,
            hasUpcomingClosure: false
        ),
    ]
}
