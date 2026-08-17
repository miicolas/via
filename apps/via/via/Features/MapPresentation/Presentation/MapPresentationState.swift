import SwiftUI

struct MapPresentationState: Equatable {
    static let collapsedDetent = PresentationDetent.height(75)
    static let searchDetent = PresentationDetent.fraction(0.45)
    static let expandedDetent = PresentationDetent.fraction(0.97)

    var screen: MapPresentationScreen = .planner(.editing(nil))
    var selectedDetent: PresentationDetent = collapsedDetent
    var draft = JourneyDraft()
    var search = PlaceSearchState.idle
    var naturalJourneyQuery = ""
    var naturalJourney: Loadable<NaturalJourneyResult> = .idle
    var naturalJourneyPrimaryJourneyID: JourneyID?
    var location: LocationState
    var journeys: Loadable<JourneyResult> = .idle
    var currentRequest: JourneyRequest?
    var displayedRequest: JourneyRequest?
    var selectedJourneyID: JourneyID?

    init(authorization: LocationAuthorization) {
        location = .idle(authorization: authorization)
    }

    var selectedStation: StationMapItem? { screen.station }

    var plannerStage: MapPlannerStage? {
        guard case .planner(let stage) = screen else { return nil }
        return stage
    }

    var activeField: MapPlaceField? {
        guard case .planner(.editing(let field)) = screen else { return nil }
        return field
    }

    var isCompact: Bool {
        selectedDetent == Self.collapsedDetent && selectedStation == nil
    }

    var stationSelectionEnabled: Bool {
        isCompact &&
            draft.destination == nil &&
            journeyResult == nil
    }

    var journeyResult: JourneyResult? { journeys.value }

    var isNaturalJourneyActive: Bool {
        naturalJourney != .idle
    }

    var presentedSheet: MapPresentationSheetRoute? {
        plannerStage == .planning || plannerStage == .results ? .journeys : nil
    }

    var selectedJourney: Journey? {
        guard let result = journeyResult else { return nil }
        return result.journeys.first { $0.id == selectedJourneyID }
            ?? result.journeys.first
    }

    var mapPresentation: JourneyMapPresentation? {
        if let request = displayedRequest,
           let journey = selectedJourney {
            return JourneyMapPresentation(request: request, journey: journey)
        }
        guard let request = currentRequest else { return nil }
        return JourneyMapPresentation(request: request, journey: nil)
    }
}
