import SwiftUI

/// A line alert carries the human label in its notification title. Rendering
/// that label as the existing route badge keeps the inbox scannable even when
/// the system notification itself is collapsed to the app icon and one line of
/// text.
struct NotificationLineBadgeView: View {
    let item: NotificationInboxItem

    var body: some View {
        LineBadgeView(route: route, size: 32)
    }

    private var route: RouteBadge {
        RouteBadge(
            id: RouteID(rawValue: item.topicID ?? "notification-line"),
            shortName: shortName,
            mode: mode,
            colorHex: colorHex,
            textColorHex: textColorHex
        )
    }

    private var lineLabel: String {
        if let titleLabel = titleLabel, !titleLabel.isLegacyIdentifier {
            return titleLabel
        }

        if let titlePrefix = item.title.split(separator: ":", maxSplits: 1).first {
            let prefix = String(titlePrefix).trimmingCharacters(in: .whitespacesAndNewlines)
            if prefix.looksLikeTransitLabel {
                return prefix
            }
        }

        return item.topicID?.split(separator: ":").last.map(String.init) ?? "?"
    }

    private var titleLabel: String? {
        guard let separator = item.title.firstIndex(of: "·") else { return nil }
        let label = String(item.title[item.title.index(after: separator)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? nil : label
    }

    private var normalizedLabel: String {
        lineLabel
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }

    private var mode: TransitMode {
        if normalizedLabel.contains("rer") { return .rer }
        if normalizedLabel.contains("transilien") { return .transilien }
        if normalizedLabel.hasPrefix("tram") { return .tram }
        if normalizedLabel.hasPrefix("bus") { return .bus }
        return .metro
    }

    private var shortName: String {
        let prefixes = ["métro", "metro", "rer", "transilien", "tramway", "tram", "bus", "ligne"]
        let folded = lineLabel.folding(options: .diacriticInsensitive, locale: .current)
        let lowercased = folded.lowercased()
        for prefix in prefixes where lowercased.hasPrefix(prefix) {
            let start = lineLabel.index(lineLabel.startIndex, offsetBy: prefix.count)
            let suffix = lineLabel[start...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !suffix.isEmpty { return String(suffix) }
        }
        return lineLabel
    }

    private var colorHex: String {
        switch mode {
        case .metro: "#FFCD00"
        case .rer: "#E3051C"
        case .transilien: "#662483"
        case .tram: "#00A88F"
        case .bus: "#6ECA97"
        }
    }

    private var textColorHex: String {
        switch mode {
        case .metro, .bus: "#000000"
        case .rer, .transilien, .tram: "#FFFFFF"
        }
    }
}

private extension String {
    var isLegacyIdentifier: Bool {
        let normalized = folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return normalized.hasPrefix("ligne idfm:") || normalized.hasPrefix("idfm:")
    }

    var looksLikeTransitLabel: Bool {
        let normalized = folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return ["métro", "metro", "rer", "transilien", "tram", "bus", "ligne"]
            .contains { normalized.hasPrefix($0) }
    }
}
