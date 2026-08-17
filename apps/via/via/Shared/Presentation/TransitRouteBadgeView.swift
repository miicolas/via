import SwiftUI

/// Badge de ligne dont la forme identifie le mode et qui conserve la couleur
/// officielle fournie par le réseau de transport.
struct TransitRouteBadgeView: View {
    let route: RouteBadge
    var size: CGFloat = 22

    var body: some View {
        Text(route.shortName)
            .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color(transitHex: route.textColorHex, fallback: .white))
            .padding(.horizontal, isCircular ? 0 : size * 0.3)
            .frame(
                minWidth: size,
                maxWidth: isCircular ? size : nil,
                minHeight: size,
                maxHeight: size
            )
            .background(
                Color(transitHex: route.colorHex, fallback: .secondary),
                in: badgeShape
            )
            .overlay {
                badgeShape.stroke(.primary.opacity(0.08), lineWidth: 0.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(route.mode.displayName), ligne \(route.shortName)")
    }

    // Le métro garde une largeur fixe pour que le cercle reste parfaitement rond.
    private var isCircular: Bool {
        route.mode == .metro
    }

    private var badgeShape: AnyShape {
        switch route.mode {
        case .metro:
            AnyShape(Circle())
        case .rer, .transilien, .tram:
            AnyShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        case .bus:
            AnyShape(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous))
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    HStack(spacing: 6) {
        TransitRouteBadgeView(
            route: RouteBadge(
                id: RouteID(rawValue: "rer-a"),
                shortName: "A",
                mode: .rer,
                colorHex: "#E2231A",
                textColorHex: "#FFFFFF"
            )
        )
        TransitRouteBadgeView(
            route: RouteBadge(
                id: RouteID(rawValue: "metro-1"),
                shortName: "1",
                mode: .metro,
                colorHex: "#FFCE00",
                textColorHex: "#000000"
            )
        )
        TransitRouteBadgeView(
            route: RouteBadge(
                id: RouteID(rawValue: "metro-14"),
                shortName: "14",
                mode: .metro,
                colorHex: "#62259D",
                textColorHex: "#FFFFFF"
            )
        )
        TransitRouteBadgeView(
            route: RouteBadge(
                id: RouteID(rawValue: "transilien-l"),
                shortName: "L",
                mode: .transilien,
                colorHex: "#7584BC",
                textColorHex: "#FFFFFF"
            )
        )
        TransitRouteBadgeView(
            route: RouteBadge(
                id: RouteID(rawValue: "tram-t3a"),
                shortName: "T3a",
                mode: .tram,
                colorHex: "#FF7F00",
                textColorHex: "#FFFFFF"
            )
        )
        TransitRouteBadgeView(
            route: RouteBadge(
                id: RouteID(rawValue: "bus-38"),
                shortName: "38",
                mode: .bus,
                colorHex: "#0055C8",
                textColorHex: "#FFFFFF"
            )
        )
    }
    .padding()
}
