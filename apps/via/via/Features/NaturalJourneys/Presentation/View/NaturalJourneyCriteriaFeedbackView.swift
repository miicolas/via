import SwiftUI

/// A successful search has already destroyed its raw phrase. Feedback can
/// therefore share only this structured, user-visible interpretation.
struct NaturalJourneyCriteriaFeedbackView: View {
    let criteria: NaturalJourneyCriteria

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("INTERPRÉTATION PARTAGÉE") {
                    LabeledContent("Départ", value: criteria.originLabel)
                    LabeledContent("Destination", value: criteria.destinationResult.name)
                    LabeledContent(
                        "Horaire",
                        value: NaturalJourneyCriteria.timeLabel(
                            criteria.requestedAt,
                            represents: criteria.datetimeRepresents,
                            anchor: criteria.timeAnchor,
                        ),
                    )
                }

                Section {
                    Text("La phrase d’origine n’a pas été conservée. Vérifie ces éléments avant de les partager.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    ShareLink(item: payload) {
                        Label("Partager le signalement", systemImage: "paperplane.fill")
                    }
                    .primaryAction()
                }
            }
            .navigationTitle("Interprétation incorrecte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    private var payload: String {
        """
        Interprétation incorrecte dans Via

        Départ : \(criteria.originLabel)
        Destination : \(criteria.destinationResult.name)
        Horaire : \(NaturalJourneyCriteria.timeLabel(
            criteria.requestedAt,
            represents: criteria.datetimeRepresents,
            anchor: criteria.timeAnchor
        ))
        Version : \(Bundle.main.marketingVersion) (\(Bundle.main.buildNumber))

        Correction attendue :
        """
    }
}
