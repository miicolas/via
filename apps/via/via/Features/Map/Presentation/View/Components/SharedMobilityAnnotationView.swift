import SwiftUI

struct SharedMobilityAnnotationView: View {
    let item: SharedMobilityItem
    var isCompact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch item {
        case .station(let dock):
            // A dock is a dock: the Vélib' layer already draws one, and two
            // pins for the same station would drift the moment either is
            // restyled.
            BikeStationAnnotationView(station: dock.station, isCompact: isCompact)
        case .vehicle(let vehicle):
            vehicleAnnotation(vehicle)
        }
    }

    private func vehicleAnnotation(_ vehicle: SharedMobilityVehicle) -> some View {
        VStack(spacing: isCompact ? 2 : 3) {
            ZStack {
                if isCompact {
                    symbol(vehicle, size: 30)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                } else {
                    detailCard(vehicle)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }

            Capsule()
                .fill(statusColor(vehicle))
                .frame(width: isCompact ? 5 : 6, height: isCompact ? 8 : 6)
        }
        .fixedSize(horizontal: true, vertical: true)
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: isCompact)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(vehicle))
        .accessibilityHint("Affiche les détails de disponibilité")
        .accessibilityAddTraits(.isButton)
    }

    private func detailCard(_ vehicle: SharedMobilityVehicle) -> some View {
        HStack(spacing: 7) {
            symbol(vehicle, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(identity(vehicle))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text(detail(vehicle))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.14), radius: 7, y: 3)
    }

    private func symbol(_ vehicle: SharedMobilityVehicle, size: CGFloat) -> some View {
        SharedMobilityProviderLogoView(provider: vehicle.provider, size: size)
    }

    private func identity(_ vehicle: SharedMobilityVehicle) -> String {
        "\(vehicle.mode.displayName) · \(vehicle.provider.displayName)"
    }

    private func detail(_ vehicle: SharedMobilityVehicle) -> String {
        var values = [vehicle.availability.displayName]
        if let battery = vehicle.batteryPercent {
            values.append("\(Int(battery.rounded())) %")
        }
        if let range = vehicle.rangeMeters {
            values.append(DistanceFormatting.text(meters: Double(range)))
        }
        return values.joined(separator: " · ")
    }

    private func statusColor(_ vehicle: SharedMobilityVehicle) -> Color {
        if let battery = vehicle.batteryPercent, battery < 20 { return .orange }
        return .accentColor
    }

    private func accessibilityLabel(_ vehicle: SharedMobilityVehicle) -> String {
        "\(identity(vehicle)), \(detail(vehicle))"
    }
}
