import SwiftUI

/// Marks a place on the drawn route: start, boarding, alighting, destination.
///
/// Alighting gets its own shape and glyph rather than a colour variation, so
/// "where do I get off" survives a monochrome or colour-blind reading.
struct JourneyStopAnnotationView: View {
    let stop: JourneyMapStop
    var isDimmed = false

    var body: some View {
        Group {
            switch stop.kind {
            case .origin:
                marker(systemImage: "location.fill", tint: .accentColor)
            case .destination:
                marker(systemImage: "flag.checkered", tint: .accentColor)
            case .board:
                bead
            case .alight:
                marker(systemImage: "arrow.down.right", tint: tint)
            }
        }
        .opacity(isDimmed ? 0.4 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var bead: some View {
        Circle()
            .fill(Color(.systemBackground))
            .frame(width: 15, height: 15)
            .overlay { Circle().strokeBorder(tint, lineWidth: 4) }
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    private func marker(systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(.systemBackground))
            .frame(width: 24, height: 24)
            .background(tint, in: Circle())
            .overlay { Circle().strokeBorder(Color(.systemBackground), lineWidth: 2.5) }
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    private var tint: Color {
        Color(transitHex: stop.colorHex ?? "", fallback: .accentColor)
    }

    private var accessibilityLabel: String {
        switch stop.kind {
        case .origin: "Départ, \(stop.name)"
        case .destination: "Arrivée, \(stop.name)"
        case .board: "Monter à \(stop.name)"
        case .alight: "Descendre à \(stop.name)"
        }
    }
}

#Preview {
    let kinds: [JourneyMapStop.Kind] = [.origin, .board, .alight, .destination]

    return HStack(spacing: 20) {
        ForEach(Array(kinds.enumerated()), id: \.offset) { index, kind in
            JourneyStopAnnotationView(
                stop: JourneyMapStop(
                    id: "preview:\(index)",
                    name: "Gare de Lyon",
                    coordinate: GeoCoordinate(latitude: 48.84, longitude: 2.37),
                    kind: kind,
                    sectionIndex: 0,
                    colorHex: "FFCE00"
                )
            )
        }
    }
    .padding()
}
