/// The single stacked sheet presented above the search surface. One optional
/// slot keeps IA research and the journey sheet mutually exclusive, so iOS never
/// has to stack a third sheet over the tab sheet.
enum SearchSheetDestination: Identifiable, Hashable {
    case naturalSearch
    case journey(JourneyID)
    case scheduledJourney(JourneyID)

    var id: String {
        switch self {
        case .naturalSearch:
            "natural"
        case let .journey(journeyID):
            "journey-\(journeyID.rawValue)"
        case let .scheduledJourney(journeyID):
            "scheduled-journey-\(journeyID.rawValue)"
        }
    }
}
