import SwiftUI

struct JourneyResultsCompactView: View {
    let journey: Journey?
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 12) {
                if let journey {
                    JourneySegmentStrip(journey: journey)

                    Text(journey.totalDurationLabel)
                        .font(.headline)
                        .monospacedDigit()
                        .fixedSize()
                } else {
                    ProgressView()
                    Text("Recherche d’itinéraires…")
                        .font(.headline)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Afficher les propositions d’itinéraire")
        .accessibilityHint("Déploie la feuille des itinéraires")
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    JourneyResultsCompactView(
        journey: JourneyResult.mapPreview.journeys.first,
        onExpand: {}
    )
    .frame(height: 75)
}
