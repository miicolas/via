import SwiftUI

struct StationRowView: View {
    let station: NetworkStation
    let routes: [RouteBadge]
    let distanceMeters: Double?
    let action: () -> Void

    var body: some View {
        ViaButton(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "tram.fill")
                    .font(.title3)
                    .foregroundStyle(ViaTheme.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(ViaFont.bodySemibold)
                        .foregroundStyle(ViaTheme.ink)

                    HStack(spacing: 5) {
                        ForEach(routes) { route in
                            LineBadgeView(route: route)
                                .scaleEffect(0.72)
                                .frame(width: 24, height: 24)
                        }
                            if let distanceMeters {
                                Text(distanceMeters.formatted(.number.precision(.fractionLength(0))) + " m")
                                .font(ViaFont.caption)
                                .foregroundStyle(ViaTheme.muted)
                        }
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ViaTheme.muted)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("via.station.\(station.id)")
    }
}
