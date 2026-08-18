import SwiftUI

struct StationAnnotationView: View {
    let item: StationMapItem

    var body: some View {
        VStack(spacing: 2) {
            VStack(alignment: .center, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                if !item.modes.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.modes, id: \.self) { mode in
                            TransitModeIconView(mode: mode)
                        }
                    }
                }

                if !item.routes.isEmpty {
                    AnnotationFlowLayout(
                        spacing: 4,
                        maximumLineWidth: 200,
                        alignment: .center
                    ) {
                        ForEach(item.routes) { route in
                            LineBadgeView(route: route, size: 14, showsLabel: false)
                        }
                    }
                }
            }
            .frame(width: 200, alignment: .center)

            Circle()
                .fill(.primary.opacity(0.55))
                .frame(width: 3, height: 3)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Affiche les lignes et les prochains passages")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        let count = item.routes.count
        return "\(item.name), \(count) ligne\(count > 1 ? "s" : "")"
    }
}
