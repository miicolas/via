import SwiftUI

struct JourneyScreen: View {
    let model: MapFeatureModel
    let onRetry: () -> Void
    let onCancel: () -> Void

    init(
        model: MapFeatureModel,
        onRetry: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.model = model
        self.onRetry = onRetry ?? { model.retryJourney() }
        self.onCancel = onCancel ?? { model.cancelJourney() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.flow.screen == .detail, let journey = model.selectedJourney,
               let request = model.journeyState.request {
                JourneyDetailView(
                    journey: journey,
                    destination: request.destination,
                    onBack: model.closeJourneyDetail,
                    onCancel: onCancel,
                    onOpenMaps: { openAppleMapsDirections(to: request.destination.coordinate) }
                )
            } else {
                JourneyResultsView(
                    state: model.journeyState,
                    onSelect: model.selectJourney,
                    onRetry: onRetry,
                    onCancel: onCancel
                )
            }
        }
    }
}
