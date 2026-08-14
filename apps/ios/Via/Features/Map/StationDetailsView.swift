import SwiftUI

struct StationDetailsView: View {
    let station: NetworkStation
    let routes: [RouteBadge]
    let departuresState: DeparturesState
    let onClose: () -> Void
    let onPlanJourney: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(station.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(ViaTheme.ink)
                        .accessibilityIdentifier("via.stationDetail.\(station.id)")
                    HStack(spacing: 6) {
                        ForEach(routes) { route in
                            LineBadgeView(route: route)
                        }
                    }
                }
                Spacer()
                ViaButton(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer la station")
            }

            Divider()

            Text("Prochains passages")
                .font(.headline)
                .foregroundStyle(ViaTheme.ink)

            DepartureBoardView(state: departuresState)

            ViaButton(
                "Voir les itinéraires",
                systemImage: "arrow.triangle.turn.up.right.diamond",
                action: onPlanJourney
            )
            .accessibilityIdentifier("via.planJourney")
        }
    }
}
