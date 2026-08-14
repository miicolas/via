import SwiftUI

struct LineRowView: View {
    let route: NetworkRoute
    let stationCount: Int

    var body: some View {
        HStack(spacing: 14) {
            LineBadgeView(
                route: RouteBadge(
                    id: route.id,
                    shortName: route.shortName,
                    mode: route.mode,
                    color: route.color,
                    textColor: route.textColor
                )
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(route.mode == .metro ? "Métro \(route.shortName)" : route.shortName)
                    .font(.headline)
                    .foregroundStyle(ViaTheme.ink)
                Text("\(stationCount) stations · réseau Via")
                    .font(.caption)
                    .foregroundStyle(ViaTheme.muted)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(ViaTheme.muted)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
