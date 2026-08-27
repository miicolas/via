import SwiftUI
import WidgetKit

/// The saved lines with what is actually happening on each — the large size,
/// the only one with room for the disruption wording.
struct FavoriteLinesListView: View {
    let entry: FavoriteLinesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FavoriteLinesVerdictLabel(lines: entry.lines)

            VStack(spacing: 8) {
                ForEach(entry.lines.prefix(6)) { line in
                    Link(destination: ViaWidgetLink.line(routeID: line.routeID)) {
                        row(for: line)
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

    private func row(for line: WidgetLineStatus) -> some View {
        HStack(spacing: 10) {
            WidgetLineTile(line: line, size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(line.condition.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(line.condition.isDisrupted ? line.condition.tint : .secondary)
                    .lineLimit(1)

                Text(line.summary ?? line.modeName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(line.modeName) ligne \(line.shortName)")
        .accessibilityValue(line.accessibilityValue)
    }
}
