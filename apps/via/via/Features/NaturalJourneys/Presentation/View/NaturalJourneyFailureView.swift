import SwiftUI

struct NaturalJourneyFailureView: View {
    let message: String
    let criteria: NaturalJourneyCriteria?
    let unresolvedDraft: NaturalJourneyDraft?
    let onRetry: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        NaturalJourneyStateCard(
            title: "Recherche impossible",
            systemImage: "wifi.exclamationmark",
        ) {
            Text(message)
                .naturalJourneyMessage()
            if let criteria {
                NaturalJourneyPreservedCriteriaView(criteria: criteria)
            } else if let unresolvedDraft {
                NaturalJourneyPreservedCriteriaView(draft: unresolvedDraft)
            }
            Button("Réessayer", action: onRetry)
                .naturalJourneyPrimaryAction()
            Button("Recherche classique", action: onClassicSearch)
                .naturalJourneySecondaryAction()
        }
    }
}
