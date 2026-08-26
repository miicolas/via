import SwiftUI

struct BikeStationAnnotationView: View {
  var station: BikeStation
  var isCompact = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 2) {
      ZStack {
        if isCompact {
          providerLogo(size: 30)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        } else {
          detailCard
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
      }

      Capsule()
        .fill(statusColor)
        .frame(width: 5, height: 8)
    }
    .fixedSize()
    .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: isCompact)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Affiche les vélos et places disponibles")
    .accessibilityAddTraits(.isButton)
  }

  private var detailCard: some View {
    HStack(spacing: 7) {
      providerLogo(size: 26)
      inventory
    }
    .padding(.leading, 5)
    .padding(.trailing, 9)
    .padding(.vertical, 5)
    .background(.thickMaterial, in: .rect(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.14), radius: 7, y: 3)
  }

  private func providerLogo(size: CGFloat) -> some View {
    SharedMobilityProviderLogoView(provider: .velib, size: size)
  }

  @ViewBuilder
  private var inventory: some View {
    if let availability = station.availability {
      HStack(spacing: 7) {
        Text("\(availability.totalBikes)")
          .font(.subheadline.weight(.bold))
          .monospacedDigit()
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)

        Divider()
          .frame(height: 16)

        HStack(spacing: 3) {
          Image(systemName: "parkingsign")
            .font(.caption2.weight(.semibold))

          Text("\(availability.docks)")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: true, vertical: false)
      }
      .fixedSize(horizontal: true, vertical: false)
      .layoutPriority(1)
    } else {
      Text("—")
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.secondary)
        .accessibilityLabel("Disponibilité inconnue")
    }
  }

  private var statusColor: Color {
    guard let availability = station.availability else { return .secondary }
    guard availability.isOperational else { return .orange }
    return availability.totalBikes > 0 ? .accentColor : .orange
  }

  private var accessibilityLabel: String {
    let detail = station.availability?.accessibilityDetail ?? "disponibilité inconnue"
    return "Station Vélib \(station.name), \(detail)"
  }
}
