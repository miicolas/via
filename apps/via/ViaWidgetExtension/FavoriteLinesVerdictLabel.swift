import SwiftUI

/// The verdict line, shared by every size that leads with it.
struct FavoriteLinesVerdictLabel: View {
    let lines: [WidgetLineStatus]

    var body: some View {
        let verdict = WidgetLinesVerdict(lines: lines)

        return Label {
            Text(verdict.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        } icon: {
            Image(systemName: verdict.systemImage)
                .foregroundStyle(verdict.tint)
        }
        .labelStyle(.titleAndIcon)
        .accessibilityElement(children: .combine)
    }
}
