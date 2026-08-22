import SwiftUI

struct JourneyDetailTimelineSection: View {
  let journey: Journey
  @Binding var expandedSectionIDs: Set<String>
  let highlightedSectionID: String?
  let onSelectSection: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Votre itinéraire")
          .font(.title2.weight(.bold))

        Text("Touchez une étape pour la retrouver sur la carte.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      JourneyTimelineView(
        journey: journey,
        expandedSectionIDs: $expandedSectionIDs,
        highlightedSectionID: highlightedSectionID,
        onSelectSection: onSelectSection
      )
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 24))
    }
  }
}
