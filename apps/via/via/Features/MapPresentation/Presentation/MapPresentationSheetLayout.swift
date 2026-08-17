import SwiftUI

enum MapPresentationSheetLayout {
    static let naturalMessageDetent = PresentationDetent.height(320)

    static let wideDetents: Set<PresentationDetent> = [
        MapPresentationState.collapsedDetent,
        MapPresentationState.expandedDetent,
    ]

    static let journeyCompactDetents: Set<PresentationDetent> = [
        MapPresentationState.collapsedDetent,
        naturalMessageDetent,
        MapPresentationState.searchDetent,
        .large,
    ]

    static func mainCompactDetents(
        for screen: MapPresentationScreen
    ) -> Set<PresentationDetent> {
        switch screen {
        case .planner(.planning), .planner(.results):
            [MapPresentationState.collapsedDetent]
        case .planner:
            [
                MapPresentationState.collapsedDetent,
                MapPresentationState.searchDetent,
                .large,
            ]
        case .station:
            [MapPresentationState.collapsedDetent, .medium, .large]
        }
    }

    static func presentedDetent(
        _ detent: PresentationDetent,
        isLargeScreen: Bool
    ) -> PresentationDetent {
        guard isLargeScreen,
              detent != MapPresentationState.collapsedDetent else { return detent }
        return MapPresentationState.expandedDetent
    }

    static func expandedDetent(isLargeScreen: Bool) -> PresentationDetent {
        isLargeScreen
            ? MapPresentationState.expandedDetent
            : MapPresentationState.searchDetent
    }

    static func journeyDetent(
        for naturalJourney: Loadable<NaturalJourneyResult>,
        isLargeScreen: Bool
    ) -> PresentationDetent {
        guard !isLargeScreen else { return MapPresentationState.expandedDetent }

        switch naturalJourney {
        case .failed(_, previous: nil),
             .loaded(.needsClarification),
             .loaded(.unsupported),
             .loaded(.unavailable),
             .loaded(.rateLimited):
            return naturalMessageDetent
        default:
            return MapPresentationState.searchDetent
        }
    }

    static func transitionedDetent(
        _ detent: PresentationDetent,
        isLargeScreen: Bool
    ) -> PresentationDetent {
        guard detent != MapPresentationState.collapsedDetent else { return detent }
        return expandedDetent(isLargeScreen: isLargeScreen)
    }
}
