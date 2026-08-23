import SwiftUI

/// Public-toilets badge of the header family: same glass square as PMR and
/// affluence, the popover carries the access conditions and where to find them.
struct StationToiletsBadge: View {
    let toilets: StationToilets
    var size: CGFloat = 22

    var body: some View {
        InfoBadgeButton(
            symbol: "toilet",
            tint: .teal,
            size: size,
            title: "Sanitaires",
            message: message,
            accessibilityLabel: "Sanitaires",
            accessibilityValue: accessibilityValue
        )
    }

    private var message: String {
        guard let detail = toilets.detail, !detail.isEmpty else { return toilets.label }
        return "\(toilets.label)\n\n\(detail)"
    }

    private var accessibilityValue: String {
        guard let detail = toilets.detail, !detail.isEmpty else { return toilets.label }
        return "\(toilets.label). \(detail)"
    }
}

#Preview {
    StationToiletsBadge(
        toilets: StationToilets(
            label: "Sanitaires disponibles",
            detail: "Accès gratuit · Accessible PMR\nÀ proximité de la sortie 3."
        ),
        size: 24
    )
    .padding()
}
