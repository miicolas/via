import SwiftUI

struct LineBadgeView: View {
    let route: RouteBadge

    var body: some View {
        Text(route.shortName)
            .font(ViaFont.captionStrong)
            .foregroundStyle(Color(hex: route.textColor))
            .frame(minWidth: 28, minHeight: 28)
            .padding(.horizontal, 4)
            .background(Color(hex: route.color), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel("Ligne \(route.shortName)")
    }
}
