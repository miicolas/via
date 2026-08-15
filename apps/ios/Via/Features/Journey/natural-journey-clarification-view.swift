import SwiftUI

struct NaturalJourneyClarificationView: View {
    let clarification: NaturalJourneyNeedsClarification
    let onResolve: (NaturalJourneyChoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Une précision", systemImage: "questionmark.circle")
                .font(ViaFont.headline)
                .foregroundStyle(ViaTheme.primary)

            ForEach(clarification.fields) { field in
                VStack(alignment: .leading, spacing: 10) {
                    Text(field.question)
                        .font(ViaFont.headline)
                        .foregroundStyle(ViaTheme.ink)

                    if field.target != .time {
                        ForEach(field.candidates) { candidate in
                            SearchResultRowView(
                                result: candidate,
                                action: {
                                    onResolve(.place(target: field.target, result: candidate))
                                }
                            )
                        }
                    }

                    if field.target == .time {
                        ViaButton(
                            "Partir à cette heure",
                            systemImage: "arrow.right",
                            action: { onResolve(.time(.departure)) }
                        )
                        ViaButton(
                            "Arriver à cette heure",
                            systemImage: "flag.checkered",
                            action: { onResolve(.time(.arrival)) }
                        )
                    } else if field.candidates.isEmpty {
                        Text("Précisez ce lieu dans la recherche.")
                            .font(ViaFont.subheadline)
                            .foregroundStyle(ViaTheme.muted)
                    }
                }
            }
        }
    }
}
