import SwiftUI

struct NaturalJourneyFailureView: View {
    let message: String
    let criteria: NaturalJourneyCriteria?
    let onRetry: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AIBadge()
            Label("Recherche impossible", systemImage: "wifi.exclamationmark")
                .font(.title2.weight(.bold))
            Text(message)
                .foregroundStyle(.secondary)
            if let criteria {
                NaturalJourneyPreservedCriteriaView(criteria: criteria)
            }
            Button("Réessayer", action: onRetry)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            Button("Recherche classique", action: onClassicSearch)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
        .padding(20)
    }
}
