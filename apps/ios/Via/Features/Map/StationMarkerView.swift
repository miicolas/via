import SwiftUI

struct StationMarkerView: View {
    let station: NetworkStation
    let routes: [RouteBadge]
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.94))
                .frame(width: isSelected ? 34 : 28, height: isSelected ? 34 : 28)
                .shadow(color: .black.opacity(0.16), radius: 5, y: 2)

            Circle()
                .fill(routeColor)
                .frame(width: isSelected ? 22 : 17, height: isSelected ? 22 : 17)

            if station.routeIds.count > 1 {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.snappy, value: isSelected)
        .accessibilityLabel(station.name)
    }

    private var routeColor: Color {
        Color(hex: routes.first?.color ?? "2F6B5B")
    }
}
