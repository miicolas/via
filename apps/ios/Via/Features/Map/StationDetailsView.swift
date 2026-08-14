import SwiftUI

struct StationDetailsView: View {
    let station: NetworkStation
    let routes: [RouteBadge]
    let departuresState: DeparturesState
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(station.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(ViaTheme.ink)
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
        }
    }
}
