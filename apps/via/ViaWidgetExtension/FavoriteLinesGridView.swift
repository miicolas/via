import SwiftUI
import WidgetKit

/// The saved lines as badges under one verdict — the Home Screen sizes.
struct FavoriteLinesGridView: View {
    let entry: FavoriteLinesEntry
    let columns: Int
    let isTappablePerLine: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FavoriteLinesVerdictLabel(lines: entry.lines)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 8, alignment: .leading),
                    count: columns
                ),
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(entry.lines.prefix(columns * 2)) { line in
                    if isTappablePerLine {
                        Link(destination: ViaWidgetLink.line(routeID: line.routeID)) {
                            WidgetLineTile(line: line)
                        }
                    } else {
                        WidgetLineTile(line: line)
                    }
                }
            }

            Spacer(minLength: 0)

            if let caption = WidgetLinesFreshness.caption(refreshedAt: entry.refreshedAt) {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
