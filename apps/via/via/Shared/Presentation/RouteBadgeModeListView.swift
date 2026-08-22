import SwiftUI

/// Line badges grouped by mode: the network's own mark on the left, the lines
/// it serves flowing to its right. A station served by métro and RER reads as
/// two named rows instead of one undifferentiated block of colour.
struct RouteBadgeModeListView: View {
    let routes: [RouteBadge]
    let size: CGFloat

    init(routes: [RouteBadge], size: CGFloat = 22) {
        self.routes = routes
        self.size = size
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(routes.modes, id: \.self) { mode in
                HStack(alignment: .top, spacing: 8) {
                    TransitModeIconView(mode: mode, size: size)

                    AnnotationFlowLayout(spacing: 6, maximumLineWidth: .infinity) {
                        ForEach(routes.filter { $0.mode == mode }) { route in
                            LineBadgeView(route: route, size: size)
                        }
                    }
                }
            }
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
            id: RouteID(rawValue: "preview:metro:4"),
            shortName: "4",
            mode: .metro,
            colorHex: "#BB4B98",
            textColorHex: "#FFFFFF"
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

    RouteBadgeModeListView(routes: routes)
        .padding()
}
