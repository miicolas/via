import SwiftUI

/// Raw text never enters telemetry. This link is the only path that can place
/// a request in a share sheet, where the traveller sees it and chooses the
/// recipient explicitly.
struct NaturalJourneyFeedbackShareLink: View {
    let phrase: String

    var body: some View {
        if let payload {
            ShareLink(item: payload) {
                Label("Envoyer cette demande", systemImage: "paperplane.fill")
            }
            .naturalJourneySecondaryAction()
            .accessibilityHint("Ouvre un aperçu avant tout envoi")
        }
    }

    private var payload: String? {
        let value = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return """
        Retour volontaire sur la recherche intelligente de Via

        Demande : « \(value) »
        Version : \(Bundle.main.marketingVersion) (\(Bundle.main.buildNumber))

        Ce qui aurait dû se passer :
        """
    }
}
