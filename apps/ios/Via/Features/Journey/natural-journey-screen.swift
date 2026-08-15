import SwiftUI

struct NaturalJourneyScreen: View {
    let model: NaturalJourneyModel
    let journeyModel: MapFeatureModel

    var body: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .interpreting:
            VStack(alignment: .leading, spacing: 16) {
                NaturalJourneyHeaderView(
                    title: "Via prépare votre trajet",
                    subtitle: "Interprétation de votre demande",
                    onCancel: journeyModel.cancelNaturalJourney
                )
                ProgressView("Recherche en cours…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .needsClarification(let clarification):
            VStack(alignment: .leading, spacing: 16) {
                NaturalJourneyHeaderView(
                    title: "Précisons le trajet",
                    subtitle: "Une réponse rapide et Via recalcule.",
                    onCancel: journeyModel.cancelNaturalJourney
                )
                NaturalJourneyClarificationView(
                    clarification: clarification,
                    onResolve: journeyModel.resolveNaturalJourney
                )
            }
        case .ready(let response):
            if journeyModel.flow.screen == .detail {
                JourneyScreen(
                    model: journeyModel,
                    onRetry: journeyModel.retryNaturalJourney,
                    onCancel: journeyModel.cancelNaturalJourney
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    NaturalJourneyAnswerView(response: response)
                    JourneyScreen(
                        model: journeyModel,
                        onRetry: journeyModel.retryNaturalJourney,
                        onCancel: journeyModel.cancelNaturalJourney
                    )
                }
            }
        case .failed(let failure):
            VStack(alignment: .leading, spacing: 16) {
                NaturalJourneyHeaderView(
                    title: "Trajet naturel",
                    subtitle: "La recherche classique reste disponible.",
                    onCancel: journeyModel.cancelNaturalJourney
                )
                NaturalJourneyFailureView(
                    failure: failure,
                    onRetry: journeyModel.retryNaturalJourney,
                    onCancel: journeyModel.cancelNaturalJourney
                )
            }
        }
    }
}
