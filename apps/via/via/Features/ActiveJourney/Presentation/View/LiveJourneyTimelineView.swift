import SwiftUI

/// Keeps the planning and live screens on the same station-by-station rail.
/// Live mode marks the section confirmed by Core Location; it never swaps the
/// rail for section cards, so the route keeps one visual language before and
/// during use.
struct LiveJourneyTimelineView: View {
  let journey: Journey
  var currentSectionIndex: Int? = nil
  var liveStopProgress: JourneyStopProgress? = nil
  @Binding var expandedSectionIDs: Set<String>
  var departureChoices: JourneyDepartureChoicesModel? = nil
  var revisableSectionIDs: Set<String> = []
  var onSelectDeparture: ((JourneyDepartureChoice, String) -> Void)? = nil
  var onRetryDepartures: (() -> Void)? = nil

  var body: some View {
    JourneyTimelineView(
      journey: journey,
      mode: currentSectionIndex.map { .live(currentSectionIndex: $0) } ?? .plan,
      liveStopProgress: liveStopProgress,
      expandedSectionIDs: $expandedSectionIDs,
      departureChoices: departureChoices,
      revisableSectionIDs: revisableSectionIDs,
      onSelectDeparture: onSelectDeparture,
      onRetryDepartures: onRetryDepartures
    )
  }
}
