import SwiftUI

struct StationAnnotationView: View {
  let item: StationMapItem
  /// The modes the active filter narrows to; empty shows every line. The full
  /// item still travels to the station sheet — only the annotation is trimmed.
  var visibleModes: Set<TransitMode> = []
  var isCompact = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Route detail belongs to the station sheet. The map only keeps enough
  /// colour to identify the annotation without turning dense areas into cards.
  private static let maximumVisibleRoutes = 2

  var body: some View {
    VStack(spacing: isCompact ? 2 : 3) {
      ZStack {
        if isCompact {
          compactMarker
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        } else {
          detailCard
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
      }

      Capsule()
        .fill(.tint)
        .frame(width: isCompact ? 5 : 6, height: isCompact ? 8 : 6)
        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
    }
    .fixedSize(horizontal: true, vertical: true)
    .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: isCompact)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Affiche les lignes et les prochains passages")
    .accessibilityAddTraits(.isButton)
  }

  private var compactMarker: some View {
    Group {
      if let mode = displayedRoutes.modes.first {
        TransitModeIconView(mode: mode, size: 20)
      } else {
        Image(systemName: "tram.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(.tint)
      }
    }
    .frame(width: 30, height: 30)
    .background(.regularMaterial, in: .circle)
    .overlay { Circle().stroke(.primary.opacity(0.08), lineWidth: 0.5) }
    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
  }

  private var detailCard: some View {
    VStack(alignment: .center, spacing: 5) {
      Text(item.name)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)
        .multilineTextAlignment(.center)

      if !displayedRoutes.isEmpty {
        HStack(spacing: 5) {
          ForEach(displayedRoutes.modes, id: \.self) { mode in
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
  }

  /// A station can pass the filter through a facility criterion alone, so an
  /// empty intersection falls back to every line rather than a bare name.
  private var displayedRoutes: [RouteBadge] {
    guard !visibleModes.isEmpty else { return item.routes }
    let matching = item.routes.filter { visibleModes.contains($0.mode) }
    return matching.isEmpty ? item.routes : matching
  }

  private var visibleRoutes: [RouteBadge] {
    Array(displayedRoutes.prefix(Self.maximumVisibleRoutes))
  }

  private var overflowCount: Int {
    max(0, displayedRoutes.count - Self.maximumVisibleRoutes)
  }

  private var accessibilityLabel: String {
    let count = displayedRoutes.count
    let modes = displayedRoutes.modes.map(\.displayName).joined(separator: ", ")
    let lines = "\(count) ligne\(count > 1 ? "s" : "")"
    return modes.isEmpty ? "\(item.name), \(lines)" : "\(item.name), \(modes), \(lines)"
  }
}
