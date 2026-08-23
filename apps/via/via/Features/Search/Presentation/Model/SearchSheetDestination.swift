/// The single stacked sheet presented above the search surface.
enum SearchSheetDestination: Identifiable, Hashable {
  case journey(JourneyID)
  case plannedJourney(JourneyID)
  case scheduledJourney(JourneyID)

  var id: String {
    switch self {
    case .journey(let journeyID):
      "journey-\(journeyID.rawValue)"
    case .plannedJourney(let journeyID):
      "planned-journey-\(journeyID.rawValue)"
    case .scheduledJourney(let journeyID):
      "scheduled-journey-\(journeyID.rawValue)"
    }
  }
}
