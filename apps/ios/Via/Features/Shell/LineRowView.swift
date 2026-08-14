import SwiftUI

struct LineRowView: View {
    let route: NetworkRoute
    let stationCount: Int
    let action: () -> Void

    var body: some View {
        ViaButton(action: action) {
            HStack(spacing: 14) {
                LineBadgeView(route: route.badge)

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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir la ligne \(route.shortName)")
        .accessibilityIdentifier("via.line.\(route.id)")
    }
}
