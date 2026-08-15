import SwiftUI

struct JourneyResultsView: View {
    let state: JourneyState
    let onSelect: (Int) -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            switch state {
            case .idle:
                EmptyView()
            case .planning:
                ProgressView("Calcul de l’itinéraire…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .failed:
                Label("L’itinéraire est indisponible.", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(ViaTheme.critical)
                ViaButton("Réessayer", systemImage: "arrow.clockwise", action: onRetry)
            case .ready(let request, let response):
                readyContent(request: request, response: response)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Itinéraire")
                    .font(ViaFont.title3)
                    .foregroundStyle(ViaTheme.ink)
                if let destination = state.request?.destination {
                    Text("Vers \(destination.name)")
                        .font(ViaFont.subheadline)
                        .foregroundStyle(ViaTheme.muted)
                }
            }
            Spacer()
            ViaButton(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer l’itinéraire")
        }
    }

    @ViewBuilder
    private func readyContent(request: JourneyRequest, response: JourneysResponse) -> some View {
        switch response.status {
        case .unavailable:
            Label("Le service d’itinéraire est indisponible.", systemImage: "wifi.exclamationmark")
                .foregroundStyle(ViaTheme.critical)
            ViaButton("Réessayer", systemImage: "arrow.clockwise", action: onRetry)
        case .noRoute where response.journeys.isEmpty:
            Label("Aucun trajet disponible maintenant.", systemImage: "map")
                .foregroundStyle(ViaTheme.muted)
            ViaButton("Recalculer", systemImage: "arrow.clockwise", action: onRetry)
        case .ready, .noRoute:
            ForEach(Array(response.journeys.enumerated()), id: \.element.id) { index, journey in
                JourneyOptionRow(journey: journey, isRecommended: index == 0) {
                    onSelect(index)
                }
            }
        }
    }
}
