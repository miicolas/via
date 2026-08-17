import SwiftUI

struct NaturalJourneyClarificationCard: View {
    let draft: NaturalJourneyDraft
    let field: NaturalJourneyClarification
    let onResolve: (
        NaturalJourneyDraft,
        SearchResult?,
        SearchResult?,
        JourneyDatetimeRepresents?
    ) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViaAIBadge()

            Label("Un détail manque", systemImage: "questionmark.bubble")
                .font(.title3.weight(.semibold))

            Text(field.question)
                .font(.body)
                .foregroundStyle(Color.viaAISecondary)
                .fixedSize(horizontal: false, vertical: true)

            choices
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .viaAISurface()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var choices: some View {
        switch field.target {
        case .origin, .destination:
            if field.candidates.isEmpty {
                Label(
                    "Aucune proposition fiable. Reformule le lieu dans la barre de recherche.",
                    systemImage: "magnifyingglass"
                )
                .font(.footnote)
                .foregroundStyle(Color.viaAISecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(field.candidates) { candidate in
                        Button {
                            resolve(candidate)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: candidate.kind == .station ? "tram.fill" : "mappin")
                                    .foregroundStyle(Color.viaAIAccent)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text(candidateDetail(candidate))
                                        .font(.footnote)
                                        .foregroundStyle(Color.viaAISecondary)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Color(uiColor: .secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Utilise ce lieu pour continuer la recherche")
                    }
                }
            }

        case .time:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { timeButtons }
                VStack(alignment: .leading, spacing: 10) { timeButtons }
            }
            .controlSize(.large)

        }
    }

    @ViewBuilder
    private var timeButtons: some View {
        Button("Partir à cette heure") {
            onResolve(draft, nil, nil, .departure)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(Color.viaAIAccent)

        Button("Arriver à cette heure") {
            onResolve(draft, nil, nil, .arrival)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(Color.viaAIAccent)
    }

    private func resolve(_ candidate: SearchResult) {
        switch field.target {
        case .origin:
            onResolve(draft, candidate, nil, nil)
        case .destination:
            onResolve(draft, nil, candidate, nil)
        case .time:
            break
        }
    }

    private func candidateDetail(_ candidate: SearchResult) -> String {
        switch candidate {
        case .station:
            "Station"
        case .address(let address):
            address.context
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    NaturalJourneyClarificationCard(
        draft: .init(
            intent: .init(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: .now,
                datetimeRepresents: .departure,
                requiredModes: [],
                excludedModes: [],
                preferredModes: []
            ),
            origin: nil,
            destination: nil
        ),
        field: .init(
            target: .destination,
            question: "Quelle destination voulais-tu dire ?",
            candidates: SearchResponse.mapPreview.results
        ),
        onResolve: { _, _, _, _ in }
    )
    .padding()
}
