import SwiftUI

struct RouteLineBadgeView: View {
    let route: RouteBadge

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color(transitHex: route.colorHex, fallback: .secondary))
            .frame(width: 11, height: 11)
            .accessibilityLabel("Ligne \(route.shortName)")
    }
}
