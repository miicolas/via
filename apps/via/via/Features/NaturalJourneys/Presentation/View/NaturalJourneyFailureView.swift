import SwiftUI

struct NaturalJourneyFailureView: View {
    let message: String
    let criteria: NaturalJourneyCriteria?
    let unresolvedDraft: NaturalJourneyDraft?
    let feedbackPhrase: String
    let onRetry: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        EmptyStateView(
            .ai(
                systemImage: "wifi.exclamationmark",
                title: "Recherche impossible",
                message: message,
            ),
        ) {
            if let criteria {
                NaturalJourneyPreservedCriteriaView(criteria: criteria)
            } else if let unresolvedDraft {
                NaturalJourneyPreservedCriteriaView(draft: unresolvedDraft)
            }
            NaturalJourneyRecoveryActions(onClassicSearch: onClassicSearch) {
                RetryButton(action: onRetry)
            }
            NaturalJourneyFeedbackShareLink(phrase: feedbackPhrase)
        }
    }
}
