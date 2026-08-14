import SwiftUI

struct JourneyScreen: View {
    let model: MapFeatureModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.flow.screen == .detail, let journey = model.selectedJourney,
               let request = model.journeyState.request {
                JourneyDetailView(
                    journey: journey,
                    destination: request.destination,
                    onBack: model.closeJourneyDetail,
                    onCancel: model.cancelJourney
                )
            } else {
                JourneyResultsView(
                    state: model.journeyState,
                    onSelect: model.selectJourney,
                    onRetry: model.retryJourney,
                    onCancel: model.cancelJourney
                )
            }
        }
    }
}
