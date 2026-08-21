import SwiftUI

/// One favorite station: its name and the lines that serve it, so the list
/// answers "where does this station take me" instead of when it was saved.
struct FavoriteStationRow: View {
    let favorite: FavoriteStation
    /// `nil` while the lines are still being resolved.
    let routes: [RouteBadge]?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(favorite.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                switch routes {
                case .none:
                    placeholderBadges
                case .some(let routes) where routes.isEmpty:
                    Text("Correspondances indisponibles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                case .some(let routes):
                    AnnotationFlowLayout(spacing: 6, maximumLineWidth: .infinity) {
                        ForEach(routes) { route in
                            LineBadgeView(route: route, size: Self.badgeSize)
                        }
                    }
                }
            }

            Spacer(minLength: 8)
        }
        .frame(minHeight: 50)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private static let badgeSize: CGFloat = 20

    private var placeholderBadges: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Self.badgeSize * 0.28, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: Self.badgeSize, height: Self.badgeSize)
            }
        }
        .accessibilityLabel("Correspondances en cours de chargement")
    }
}

#Preview("Favori") {
    let routes = StationsArea.mapPreview
    let station = routes.stations[1]

    List {
        FavoriteStationRow(
            favorite: FavoriteStation(
                stationID: station.id.rawValue,
                name: station.name,
                coordinate: station.coordinate,
                savedAt: .now,
                updatedAt: .now
            ),
            routes: StationRouteCatalog(routes: routes.routes).routes(for: station.routeIDs)
        )
    }
}
