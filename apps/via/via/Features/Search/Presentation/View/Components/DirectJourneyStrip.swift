import SwiftUI

/// Walking and cycling, kept beside the search rather than in it: a titled row
/// of tiles above the transit list, read the way the saved lines are, so the
/// itineraries the traveller came for stay the answer.
struct DirectJourneyStrip: View {
  let journeys: [Journey]
  var selectedJourneyID: JourneyID?
  var onSelect: (Journey) -> Void

  @State private var selectionTick = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("À pied ou à vélo")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)

      ScrollView(.horizontal) {
        HStack(spacing: 12) {
          ForEach(journeys) { journey in
            Button {
              selectionTick += 1
              onSelect(journey)
            } label: {
              DirectJourneyTile(
                journey: journey,
                isSelected: selectedJourneyID == journey.id
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 4)
      }
      .scrollIndicators(.hidden)
      .scrollClipDisabled()
    }
    // Retaining an itinerary opens the detail over the map: the decision that
    // ends the search.
    .haptic(Haptic.commit, on: selectionTick)
  }
}

#Preview {
  DirectJourneyStrip(
    journeys: [.mapPreviewWalking, .mapPreviewCycling],
    onSelect: { _ in }
  )
  .padding()
}
