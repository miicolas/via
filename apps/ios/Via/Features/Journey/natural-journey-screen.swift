import SwiftUI

struct NaturalJourneyScreen: View {
    let model: MapFeatureModel

    var body: some View {
        switch model.naturalJourneyState {
        case .idle:
            EmptyView()
        case .interpreting:
            VStack(alignment: .leading, spacing: 16) {
                NaturalJourneyHeaderView(
                    title: "Via prépare votre trajet",
                    subtitle: "Interprétation de votre demande",
                    onCancel: model.cancelNaturalJourney
                )
                ProgressView("Recherche en cours…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .needsClarification(let clarification):
            VStack(alignment: .leading, spacing: 16) {
                NaturalJourneyHeaderView(
                    title: "Précisons le trajet",
                    subtitle: "Une réponse rapide et Via recalcule.",
                    onCancel: model.cancelNaturalJourney
                )
                NaturalJourneyClarificationView(
                    clarification: clarification,
                    onResolve: model.resolveNaturalJourney
                )
            }
        case .ready(let response):
            if model.flow.screen == .detail {
                JourneyScreen(
                    model: model,
                    onRetry: model.retryNaturalJourney,
                    onCancel: model.cancelNaturalJourney
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    NaturalJourneyAnswerView(response: response)
                    JourneyScreen(
                        model: model,
                        onRetry: model.retryNaturalJourney,
                        onCancel: model.cancelNaturalJourney
                    )
                }
            }
        case .failed(let failure):
            VStack(alignment: .leading, spacing: 16) {
                NaturalJourneyHeaderView(
                    title: "Trajet naturel",
                    subtitle: "La recherche classique reste disponible.",
                    onCancel: model.cancelNaturalJourney
                )
                NaturalJourneyFailureView(
                    failure: failure,
                    onRetry: model.retryNaturalJourney,
                    onCancel: model.cancelNaturalJourney
                )
            }
        }
    }
}
