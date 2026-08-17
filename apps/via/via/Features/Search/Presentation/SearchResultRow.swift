import Foundation
import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.kind.iconSystemImage)
                .font(.headline)
                .foregroundStyle(result.kind.iconColor)
                .frame(width: 34, height: 34)
                .background(.quaternary, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !routes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 4) {
                                ForEach(routes.prefix(8)) { route in
                                    TransitRouteBadgeView(route: route, size: 20)
                                }
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
            }

            Spacer(minLength: 8)

            if let distance = distanceText {
                Text(distance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var subtitle: String? {
        guard case .address(let address) = result else { return nil }
        return address.context
    }

    private var routes: [RouteBadge] {
        guard case .station(let station) = result else { return [] }
        return station.routes
    }

    private var distanceText: String? {
        let meters: Double?
        switch result {
        case .station(let station): meters = station.distanceMeters
        case .address(let address): meters = address.distanceMeters
        }
        guard let meters else { return nil }
        if meters < 1_000 {
            return "\(Int((meters / 10).rounded()) * 10) m"
        }
        return String(format: "%.1f km", meters / 1_000)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    SearchResultRow(result: SearchResponse.mapPreview.results[0])
        .padding()
}
