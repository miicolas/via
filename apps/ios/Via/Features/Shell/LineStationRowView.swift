import SwiftUI

struct LineStationRowView: View {
    let station: NetworkStation
    let route: NetworkRoute
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(hex: route.color))
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)

                if !isLast {
                    Rectangle()
                        .fill(Color(hex: route.color).opacity(0.35))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(ViaFont.bodySemibold)
                    .foregroundStyle(ViaTheme.ink)

                if station.routeIds.count > 1 {
                    Text("Correspondance")
                        .font(ViaFont.caption)
                        .foregroundStyle(ViaTheme.muted)
                }
            }
            .padding(.bottom, 14)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            station.routeIds.count > 1
                ? "\(station.name), correspondance"
                : station.name
        )
    }
}
