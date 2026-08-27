import SwiftUI
import WidgetKit

/// The state of the lines the traveller follows, at a glance.
struct FavoriteLinesWidgetView: View {
    let entry: FavoriteLinesEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(ViaWidgetLink.lines)
    }

    @ViewBuilder
    private var content: some View {
        if entry.savedLineCount == 0 {
            switch family {
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                WidgetEmptyAccessoryView(
                    systemImage: "tram",
                    title: "Aucune ligne suivie",
                    family: family
                )
            default:
                WidgetEmptyStateView.noFavoriteLine
            }
        } else if entry.lines.isEmpty {
            // Filtered to disruptions only, and there are none. Good news, not
            // an absence — it never borrows the empty state's wording.
            FavoriteLinesAllClearView(savedLineCount: entry.savedLineCount, family: family)
        } else {
            switch family {
            case .systemLarge:
                FavoriteLinesListView(entry: entry)
            case .systemMedium:
                FavoriteLinesGridView(entry: entry, columns: 4, isTappablePerLine: true)
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                FavoriteLinesAccessoryView(entry: entry, family: family)
            default:
                FavoriteLinesGridView(entry: entry, columns: 2, isTappablePerLine: false)
            }
        }
    }
}
