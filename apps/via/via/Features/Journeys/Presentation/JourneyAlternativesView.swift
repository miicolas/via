import SwiftUI

struct JourneyAlternativesView: View {
    let state: Loadable<JourneyResult>
    let selectedJourneyID: JourneyID?
    let onSelect: (JourneyID) -> Void
    let onRetry: () -> Void
    var onGo: (() -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                statusMessage

                if let result = state.value {
                    resultContent(result)
                } else if case .loading = state {
                    JourneyLoadingSkeleton()
                } else if case .failed(let error, _) = state {
                    blockingError(for: error)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.secondary.opacity(0.05))
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch state {
        case .loading(let previous) where previous != nil:
            ViaLoadingStatus(label: "Actualisation des itinéraires…")
                .padding(.bottom, 14)
        case .failed(_, let previous) where previous != nil:
            HStack(alignment: .top, spacing: 10) {
                Label(
                    "Impossible d’actualiser. Les derniers itinéraires restent affichés.",
                    systemImage: "wifi.exclamationmark"
                )
                .foregroundStyle(.orange)
                Spacer()
                Button("Réessayer", action: onRetry)
            }
            .padding(.bottom, 14)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func resultContent(_ result: JourneyResult) -> some View {
        if result.source == .theoretical {
            Label(
                "Horaires théoriques : les données temps réel sont indisponibles.",
                systemImage: "clock.badge.questionmark"
            )
            .font(.footnote)
            .foregroundStyle(.orange)
            .padding(.bottom, 14)
        }

        switch result.status {
        case .ready where !result.journeys.isEmpty:
            let journeys = Array(result.journeys.prefix(4))
            let hero = journeys.first { $0.id == selectedJourneyID } ?? journeys[0]
            let others = journeys.filter { $0.id != hero.id }

            JourneyAlternativeCard(journey: hero, onGo: onGo)

            if !others.isEmpty {
                ViaSectionHeader("Autres itinéraires")
                    .padding(.top, 26)
                    .padding(.bottom, 4)

                ForEach(others) { journey in
                    Button {
                        onSelect(journey.id)
                    } label: {
                        JourneyAlternativeRow(journey: journey)
                    }
                    .buttonStyle(.plain)

                    if journey.id != others.last?.id {
                        Divider()
                    }
                }
            }
        case .ready, .noRoute:
            ContentUnavailableView(
                "Aucun itinéraire",
                systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
                description: Text("Modifie le départ ou l’arrivée, puis réessaie.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        case .unavailable:
            blockingError(for: .unavailable)
        }
    }

    private func blockingError(for error: ViaError) -> some View {
        let presentation = JourneyErrorPresentation(error: error)
        return ContentUnavailableView {
            Label(presentation.title, systemImage: presentation.systemImage)
        } description: {
            Text(presentation.message)
        } actions: {
            Button("Réessayer", systemImage: "arrow.clockwise", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview {
    JourneyAlternativesView(
        state: .loaded(.mapPreview),
        selectedJourneyID: JourneyResult.mapPreview.journeys.first?.id,
        onSelect: { _ in },
        onRetry: {},
        onGo: {}
    )
}

#Preview("Chargement") {
    JourneyAlternativesView(
        state: .loading(previous: nil),
        selectedJourneyID: nil,
        onSelect: { _ in },
        onRetry: {},
        onGo: {}
    )
}
