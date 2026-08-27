import SwiftUI
import WidgetKit

/// The saved lines on the Lock Screen, where there is room for the verdict and
/// at most the line behind it.
struct FavoriteLinesAccessoryView: View {
    let entry: FavoriteLinesEntry
    let family: WidgetFamily

    var body: some View {
        let verdict = WidgetLinesVerdict(lines: entry.lines)

        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: verdict.systemImage)
                        .font(.caption)
                    Text("\(disruptedCount)")
                        .font(.headline.monospacedDigit())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Lignes suivies")
            .accessibilityValue(verdict.title)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(verdict.title, systemImage: verdict.systemImage)
                    .font(.headline)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Lignes suivies")
            .accessibilityValue("\(verdict.title). \(detail)")

        default:
            Text("\(verdict.title) · \(detail)")
                .accessibilityLabel("Lignes suivies")
                .accessibilityValue("\(verdict.title). \(detail)")
        }
    }

    private var disruptedCount: Int {
        entry.lines.count { $0.condition.isDisrupted }
    }

    /// The worst line's own wording when there is one, and the reassuring
    /// count when every saved line runs.
    private var detail: String {
        if let worst = entry.lines.first, worst.condition.isDisrupted {
            return worst.summary ?? "\(worst.modeName) \(worst.shortName) · \(worst.condition.title)"
        }

        return entry.savedLineCount == 1
            ? "1 ligne suivie"
            : "\(entry.savedLineCount) lignes suivies"
    }
}
