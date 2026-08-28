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
            let horizontalPadding: CGFloat = route.shortName.count > 2 ? 4 : 0

            Text(route.shortName)
                .font(.system(size: max(11, size * 0.5), weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .truncationMode(.tail)
                .allowsTightening(true)
                .minimumScaleFactor(0.75)
                .foregroundStyle(Color(transitHex: route.textColorHex, fallback: .white))
                // A malformed or unusually long route label must not push the
                // destination, station name, or neighbouring badge off-screen.
                // Keep the usual short labels intrinsic, but give every badge a
                // finite ceiling and let the label truncate inside it.
                .frame(
                    minWidth: max(0, size - horizontalPadding * 2),
                    maxWidth: max(size, size * 2 - horizontalPadding * 2),
                    minHeight: size
                )
                .padding(.horizontal, horizontalPadding)
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
