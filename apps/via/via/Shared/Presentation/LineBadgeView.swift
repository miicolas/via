import SwiftUI

struct LineBadgeView: View {
    let route: RouteBadge
    let size: CGFloat
    let showsLabel: Bool

    init(route: RouteBadge, size: CGFloat = 22, showsLabel: Bool = true) {
        self.route = route
        self.size = size
        self.showsLabel = showsLabel
    }

    var body: some View {
        content
            .background(
                Color(transitHex: route.colorHex, fallback: .secondary),
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(route.mode.displayName) ligne \(route.shortName)")
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
    }

    @ViewBuilder
    private var content: some View {
        if showsLabel {
            Text(route.shortName)
                .font(.system(size: max(11, size * 0.5), weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(Color(transitHex: route.textColorHex, fallback: .white))
                .frame(minWidth: size, minHeight: size)
                .padding(.horizontal, route.shortName.count > 2 ? 4 : 0)
        } else {
            Color.clear
                .frame(width: size, height: size)
        }
    }
}

#Preview {
    let routes = [
        RouteBadge(
            id: RouteID(rawValue: "preview:metro:1"),
            shortName: "1",
            mode: .metro,
            colorHex: "#FFCD00",
            textColorHex: "#000000"
        ),
        RouteBadge(
            id: RouteID(rawValue: "preview:rer:A"),
            shortName: "A",
            mode: .rer,
            colorHex: "#E3051C",
            textColorHex: "#FFFFFF"
        ),
        RouteBadge(
            id: RouteID(rawValue: "preview:bus:67"),
            shortName: "67",
            mode: .bus,
            colorHex: "#6ECA97",
            textColorHex: "#000000"
        ),
    ]

    HStack(spacing: 8) {
        ForEach(routes) { route in
            LineBadgeView(route: route)
        }
    }
    .padding()
}
