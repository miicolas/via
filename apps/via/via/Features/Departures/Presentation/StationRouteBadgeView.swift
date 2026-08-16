import SwiftUI

struct StationRouteBadgeView: View {
    let route: RouteBadge

    var body: some View {
        HStack(spacing: 6) {
            route.mode.glyph
                .font(.caption2.weight(.heavy))

            Text(route.shortName)
                .font(.headline.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(
            Color(transitHex: route.textColorHex, fallback: .white)
        )
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(transitHex: route.colorHex, fallback: .secondary))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(route.mode.displayName), ligne \(route.shortName)")
    }
}
