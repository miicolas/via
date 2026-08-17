import Foundation

enum OnboardingDemoFixture {
    static let query = "Je veux arriver à La Défense avant 9 h"

    static let destination: SearchResult = SearchResponse.mapPreview.results[1]
    static let journey: Journey = JourneyResult.mapPreview.journeys[0]

    static let request: JourneyRequest = {
        let origin = journey.sections.first?.from.coordinate ?? .paris

        return JourneyRequest(
            origin: origin,
            destination: JourneyPlaceSelection(destination).journeyDestination,
            limit: 1,
            requestedAt: journey.arrivalAt.addingTimeInterval(60),
            datetimeRepresents: .arrival
        )
    }()

    static let mapPresentation = JourneyMapPresentation(
        request: request,
        journey: journey
    )

    static let naturalJourneyResult: NaturalJourneyResult = {
        let interpretation = NaturalJourneyInterpretation(
            originLabel: "Ta position",
            destination: JourneyPlaceSelection(destination).journeyDestination,
            destinationResult: destination,
            requestedAt: request.requestedAt ?? journey.arrivalAt,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [],
            preferredModes: []
        )

        return .ready(
            answer: "Prends le RER A puis la ligne 1 jusqu’à La Défense.",
            answerSource: .deterministic,
            preferenceNotice: nil,
            interpretation: interpretation,
            journeys: JourneyResult.mapPreview
        )
    }()
}

private extension GeoCoordinate {
    static let paris = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
}
