import SwiftUI

struct StationAnnotationView: View {
    let item: StationMapItem

    /// A station served by a dozen lines would otherwise stack badges into a
    /// block taller than the label it belongs to: past this count the rest
    /// collapses into a single `+n`, so every annotation stays one short row.
    private static let maximumVisibleRoutes = 4

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
                    HStack(spacing: 4) {
                        ForEach(visibleRoutes) { route in
                            LineBadgeView(route: route, size: 14, showsLabel: false)
                        }

                        if overflowCount > 0 {
                            LineBadgeOverflowView(count: overflowCount, size: 14)
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

    private var visibleRoutes: [RouteBadge] {
        Array(item.routes.prefix(Self.maximumVisibleRoutes))
    }

    private var overflowCount: Int {
        max(0, item.routes.count - Self.maximumVisibleRoutes)
    }

    private var accessibilityLabel: String {
        let count = item.routes.count
        return "\(item.name), \(count) ligne\(count > 1 ? "s" : "")"
    }
}
