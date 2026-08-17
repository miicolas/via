import SwiftUI

struct DepartureLineRow: View {
    let route: RouteBadge
    let groups: [DepartureGroup]
    let source: DepartureBoard.Source
    let now: Date

    var body: some View {
        let directions = departureDirectionSnapshots(groups: groups, now: now)

        VStack(alignment: .leading, spacing: 8) {
            TransitRouteBadgeView(route: route, size: 30)

            Divider()

            if directions.isEmpty {
                Text("Aucun passage annoncé")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 9)
                    .accessibilityLabel(
                        "Ligne \(route.shortName), aucun passage annoncé"
                    )
            } else {
                ForEach(directions) { direction in
                    DepartureDirectionRow(
                        destination: direction.destination,
                        minutes: direction.minutes,
                        source: source
                    )

                    if direction.id != directions.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .viaGlassCard()
    }
}
