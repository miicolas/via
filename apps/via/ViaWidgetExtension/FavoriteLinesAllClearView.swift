import SwiftUI
import WidgetKit

/// Every saved line runs. The widget says so rather than going blank.
struct FavoriteLinesAllClearView: View {
    let savedLineCount: Int
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Tout roule")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
            }
            .accessibilityLabel("Lignes suivies")
            .accessibilityValue("Tout roule")
        case .accessoryRectangular:
            Label("Tout roule", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Lignes suivies")
                .accessibilityValue("Tout roule")
        default:
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                Text("Tout roule")
                    .font(.subheadline.weight(.semibold))

                Text(
                    savedLineCount == 1
                        ? "Votre ligne circule normalement"
                        : "Vos \(savedLineCount) lignes circulent normalement"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Lignes suivies")
            .accessibilityValue("Tout roule")
        }
    }
}
