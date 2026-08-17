import SwiftUI

struct NaturalJourneyAnswerCard: View {
    let journey: Journey
    let result: NaturalJourneyResult
    let isOriginalAnswer: Bool
    let onGo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViaAIBadge()

            Text(displayedAnswer)
                .font(.title2.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            JourneySegmentStrip(journey: journey)

            Text(timingSummary)
                .font(.title3.weight(.semibold))
                .foregroundStyle(timingColor)
                .monospacedDigit()

            notices

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { actionButtons }
                VStack(alignment: .leading, spacing: 10) { actionButtons }
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .viaAISurface()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var notices: some View {
        if isOriginalAnswer, let preferenceNotice {
            Label(preferenceNotice, systemImage: "info.circle.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if !journey.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(journey.warnings.enumerated()), id: \.offset) { item in
                    Label(item.element, systemImage: "exclamationmark.triangle.fill")
                }
            }
            .font(.footnote)
            .foregroundStyle(.orange)
        }
    }

    private var displayedAnswer: String {
        if isOriginalAnswer, case .ready(let answer, _, _, _) = result {
            return answer
        }

        let origin = journey.sections.first?.from.name ?? "Départ"
        let destination = journey.sections.last?.to.name ?? "destination"
        let lines = journey.sections.compactMap { $0.route?.shortName }
        if lines.isEmpty {
            return "Une alternative de \(origin) à \(destination)."
        }
        return "Une alternative via \(lines.joined(separator: " puis ")) jusqu’à \(destination)."
    }

    private var timingSummary: String {
        guard case .ready(_, _, let interpretation, _) = result else {
            return "Arrivée à \(formatted(journey.arrivalAt))"
        }

        switch interpretation.datetimeRepresents {
        case .arrival:
            let status = journey.arrivalAt <= interpretation.requestedAt
                ? "dans les temps"
                : "après l’heure demandée"
            return "Arrivée à \(formatted(journey.arrivalAt)), \(status)."
        case .departure:
            return "Départ à \(formatted(journey.departureAt))."
        }
    }

    private var timingColor: Color {
        guard case .ready(_, _, let interpretation, _) = result,
              interpretation.datetimeRepresents == .arrival else { return .viaAIAccent }
        return journey.arrivalAt <= interpretation.requestedAt ? .viaAIAccent : .orange
    }

    private var preferenceNotice: String? {
        guard case .ready(_, let notice, _, _) = result else { return nil }
        return notice
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button("Y aller", systemImage: "location.fill", action: onGo)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.viaAIAccent)

        Button("Répondre", systemImage: "message") {}
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(Color.viaAIAccent)
            .disabled(true)
            .accessibilityHint("Le suivi de conversation sera disponible prochainement")
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let destination = SearchResponse.mapPreview.results[1]
    NaturalJourneyAnswerCard(
        journey: JourneyResult.mapPreview.journeys[0],
        result: .ready(
            answer: "Prends le RER A puis la ligne 1 jusqu’à La Défense.",
            preferenceNotice: "Cet itinéraire respecte l’heure demandée.",
            interpretation: NaturalJourneyInterpretation(
                originLabel: "Ta position",
                destination: JourneyPlaceSelection(destination).journeyDestination,
                destinationResult: destination,
                requestedAt: .now.addingTimeInterval(4_000),
                datetimeRepresents: .arrival,
                requiredModes: [],
                excludedModes: [],
                preferredModes: []
            ),
            journeys: .mapPreview
        ),
        isOriginalAnswer: true,
        onGo: {}
    )
    .padding()
}
