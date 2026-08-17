import SwiftUI

struct JourneyResultsSheet: View {
    let model: MapPresentationModel
    let isLargeScreen: Bool

    @State private var detent: PresentationDetent

    init(model: MapPresentationModel, isLargeScreen: Bool) {
        self.model = model
        self.isLargeScreen = isLargeScreen
        _detent = State(
            initialValue: MapPresentationSheetLayout.journeyDetent(
                for: model.state.naturalJourney,
                isLargeScreen: isLargeScreen
            )
        )
    }

    var body: some View {
        Group {
            if detent == MapPresentationState.collapsedDetent {
                JourneyResultsCompactView(
                    journey: model.state.selectedJourney,
                    onExpand: {
                        detent = MapPresentationSheetLayout.journeyDetent(
                            for: model.state.naturalJourney,
                            isLargeScreen: isLargeScreen
                        )
                    }
                )
            } else {
                JourneyResultsExpandedView(
                    model: model,
                    onCollapse: {
                        detent = MapPresentationState.collapsedDetent
                    }
                )
            }
        }
        .adaptiveSheetPresentation(
            compactDetents: MapPresentationSheetLayout.journeyCompactDetents,
            wideDetents: MapPresentationSheetLayout.wideDetents,
            selection: $detent,
            isLargeScreen: isLargeScreen
        )
        .onChange(of: isLargeScreen) { _, isLargeScreen in
            guard detent != MapPresentationState.collapsedDetent else { return }
            detent = MapPresentationSheetLayout.journeyDetent(
                for: model.state.naturalJourney,
                isLargeScreen: isLargeScreen
            )
        }
        .onChange(of: model.state.naturalJourney) { _, naturalJourney in
            guard detent != MapPresentationState.collapsedDetent else { return }
            detent = MapPresentationSheetLayout.journeyDetent(
                for: naturalJourney,
                isLargeScreen: isLargeScreen
            )
        }
    }
}

#Preview {
    JourneyResultsSheet(
        model: PreviewDependencies().mapPresentation,
        isLargeScreen: false
    )
}
