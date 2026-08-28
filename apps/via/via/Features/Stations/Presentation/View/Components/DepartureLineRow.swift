import SwiftUI

struct DepartureLineRow: View {
    let route: RouteBadge
    let departure: StationDeparture?
    let source: DepartureBoard.Source

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            LineBadgeView(route: route, size: 36)
                .frame(minWidth: 36, alignment: .leading)
                .layoutPriority(1)

            if let departure {
                Text(departure.destination)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DepartureTimingView(
                    departure: departure,
                    source: source
                )
            } else {
                Text(source == .unavailable ? "Horaires indisponibles" : "Aucun passage à venir")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }
}
