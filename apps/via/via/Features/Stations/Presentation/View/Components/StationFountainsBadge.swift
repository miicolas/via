import SwiftUI

/// Drinking-water badge for a station's header. IDFM currently locates each
/// fountain at its station rather than at an entrance, so the popover carries
/// that precision caveat instead of implying an exact indoor position.
struct StationFountainsBadge: View {
    let fountains: StationFountains
    var size: CGFloat = 22

    var body: some View {
        InfoBadgeButton(
            symbol: "drop.fill",
            tint: fountains.status == .available ? .blue : .red,
            size: size,
            title: "Eau potable",
            message: message,
            accessibilityLabel: "Eau potable",
            accessibilityValue: accessibilityValue
        )
    }

    private var message: String {
        guard let detail = fountains.detail, !detail.isEmpty else { return fountains.label }
        return "\(fountains.label)\n\n\(detail)"
    }

    private var accessibilityValue: String {
        guard let detail = fountains.detail, !detail.isEmpty else { return fountains.label }
        return "\(fountains.label). \(detail)"
    }
}

#Preview {
    HStack(spacing: 10) {
        StationFountainsBadge(
            fountains: StationFountains(
                status: .available,
                label: "Fontaine d’eau potable à proximité",
                detail: "Accessible PMR · Remplissage de gourde possible"
            ),
            size: 24
        )

        StationFountainsBadge(
            fountains: StationFountains(
                status: .unavailable,
                label: "Fontaine d’eau signalée indisponible",
                detail: nil
            ),
            size: 24
        )
    }
    .padding()
}
