import SwiftUI

struct StationAnnotationView: View {
  let item: StationMapItem

  /// Route detail belongs to the station sheet. The map only keeps enough
  /// colour to identify the annotation without turning dense areas into cards.
  private static let maximumVisibleRoutes = 2

  var body: some View {
    VStack(spacing: 3) {
      VStack(alignment: .center, spacing: 5) {
        Text(item.name)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
          .multilineTextAlignment(.center)

        if !item.routes.isEmpty {
          HStack(spacing: 5) {
            ForEach(item.modes, id: \.self) { mode in
              TransitModeIconView(mode: mode, size: 13)
            }

            HStack(spacing: 3) {
              ForEach(visibleRoutes) { route in
                LineBadgeView(route: route, size: 13, showsLabel: false)
              }

              if overflowCount > 0 {
                LineBadgeOverflowView(count: overflowCount, size: 13)
              }
            }
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .frame(maxWidth: 140)
      .background(.regularMaterial, in: .rect(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(.primary.opacity(0.08), lineWidth: 0.5)
      }

      Circle()
        .fill(.tint)
        .frame(width: 6, height: 6)
        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
    }
    .fixedSize(horizontal: true, vertical: true)
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
    let modes = item.modes.map(\.displayName).joined(separator: ", ")
    let lines = "\(count) ligne\(count > 1 ? "s" : "")"
    return modes.isEmpty ? "\(item.name), \(lines)" : "\(item.name), \(modes), \(lines)"
  }
}
