import SwiftUI

struct ActiveJourneyAlternativesView: View {
    let alternative: ActiveJourneyAlternative
    let onSelect: (Journey) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(alternative.journeys) { journey in
                        Button {
                            onSelect(journey)
                            dismiss()
                        } label: {
                            JourneySummaryCard(
                                journey: journey,
                                source: alternative.source
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Remplace le trajet actif par cette option")
                    }
                }
                .padding(16)
            }
            .navigationTitle("Autres itinéraires")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
