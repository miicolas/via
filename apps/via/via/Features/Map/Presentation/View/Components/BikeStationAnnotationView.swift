import SwiftUI

struct BikeStationAnnotationView: View {
    let station: BikeStation

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "bicycle")
                    .font(.caption.weight(.semibold))

                if let availability = station.availability {
                    Text("\(availability.totalBikes)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: .capsule)
            .overlay {
                Capsule()
                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
            }

            Circle()
                .fill(.tint)
                .frame(width: 6, height: 6)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Affiche les vélos et bornettes disponibles")
        .accessibilityAddTraits(.isButton)
    }

    private var foregroundStyle: Color {
        guard let availability = station.availability else { return Color.secondary }
        return availability.isOperational && availability.totalBikes > 0 ? Color.green : Color.orange
    }

    private var accessibilityLabel: String {
        let detail = station.availability?.accessibilityDetail ?? "disponibilité inconnue"
        return "Station Vélib \(station.name), \(detail)"
    }
}
