import SwiftUI

struct ChatItineraryCardView: View {
    let itinerary: ChatItinerary
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Itinéraire trouvé", systemImage: "map")
                    .font(.headline)
                    .foregroundStyle(ViaTheme.ink)
                Spacer()
                Text(itinerary.destination.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ViaTheme.primary)
            }

            if let journey = itinerary.response.journeys.first {
                HStack(spacing: 14) {
                    Text(journeyMinutes(journey))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ViaTheme.ink)
                    Text(journey.transferCount == 0 ? "direct" : "\(journey.transferCount) correspondance(s)")
                        .font(.subheadline)
                        .foregroundStyle(ViaTheme.body)
                }
            }

            ViaButton("Voir le détail", systemImage: "arrow.right", action: onOpen)
                .accessibilityIdentifier("via.chat.openItinerary")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func journeyMinutes(_ journey: Journey) -> String {
        let minutes = max(1, Int(ceil(Double(journey.durationSeconds) / 60)))
        return "\(minutes) min"
    }
}
