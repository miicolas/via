import SwiftUI

struct SearchResultRowView: View {
    let result: SearchResult
    let action: () -> Void

    var body: some View {
        ViaButton(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .foregroundStyle(ViaTheme.primary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ViaTheme.ink)

                    switch result {
                    case .station(let station):
                        HStack(spacing: 4) {
                            ForEach(station.routes) { route in
                                LineBadgeView(route: route)
                                    .scaleEffect(0.64)
                                    .frame(width: 22, height: 22)
                            }
                            if let distanceMeters = station.distanceMeters {
                                Text(distanceMeters.formatted(.number.precision(.fractionLength(0))) + " m")
                                    .font(.caption)
                                    .foregroundStyle(ViaTheme.muted)
                            }
                        }
                    case .address(let address):
                        Text(address.context)
                            .font(.caption)
                            .foregroundStyle(ViaTheme.muted)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ViaTheme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("via.searchResult.\(result.id)")
    }

    private var symbolName: String {
        switch result {
        case .station: "tram.fill"
        case .address: "mappin.and.ellipse"
        }
    }
}
