import SwiftUI

struct NaturalJourneyDecisionView: View {
    let decision: NaturalJourneyDecision
    let onConfirmCurrentLocation: () -> Void
    let onResolveMode: (TransitMode, NaturalJourneyModeConstraint) -> Void
    let onContinueWithoutUnsupported: () -> Void
    let onResolveTimeConflict: (RouteTimeConstraint) -> Void
    let onModify: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AIBadge()
            content
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        switch decision {
        case .currentLocation:
            Label("Choisir le départ", systemImage: "location.circle")
                .font(.title2.weight(.bold))
            Text("Aucune origine n’est indiquée. Veux-tu partir de ta position actuelle ?")
                .foregroundStyle(.secondary)
            Button("Utiliser ma position", systemImage: "location.fill", action: onConfirmCurrentLocation)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            Button("Indiquer une autre origine", action: onModify)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

        case let .modeConflict(mode, choices):
            Label("Contraintes contradictoires", systemImage: "arrow.trianglehead.branch")
                .font(.title2.weight(.bold))
            Text("Deux contraintes se contredisent pour \(mode.naturalLanguageNameWithArticle). Laquelle veux-tu conserver ?")
                .foregroundStyle(.secondary)
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                if index == 0 {
                    modeChoiceButton(choice, mode: mode)
                        .buttonStyle(.borderedProminent)
                } else {
                    modeChoiceButton(choice, mode: mode)
                        .buttonStyle(.bordered)
                }
            }

        case let .unsupportedConstraints(constraints):
            Label("Contrainte indisponible", systemImage: "exclamationmark.triangle")
                .font(.title2.weight(.bold))
            Text(constraints.joined(separator: " · "))
                .font(.headline)
            Text("Via ne sait pas encore appliquer cette contrainte.")
                .foregroundStyle(.secondary)
            Button("Continuer sans cette contrainte", action: onContinueWithoutUnsupported)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            Button("Modifier la demande", action: onModify)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

        case let .pastDate(date):
            Label("Cette heure est passée", systemImage: "clock.badge.exclamationmark")
                .font(.title2.weight(.bold))
            Text(date.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            Text("La date était explicite, Via ne la déplacera pas silencieusement.")
                .foregroundStyle(.secondary)
            Button("Modifier la demande", action: onModify)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)

        case let .timeConflict(first, second):
            Label("Choisis la contrainte horaire", systemImage: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                .font(.title2.weight(.bold))
            Text("Le moteur accepte une heure de départ ou une heure d’arrivée.")
                .foregroundStyle(.secondary)
            timeConstraintButton(first)
            timeConstraintButton(second)
        }
    }

    private func modeChoiceButton(
        _ choice: NaturalJourneyModeConstraint,
        mode: TransitMode,
    ) -> some View {
        Button(choice.buttonTitle(for: mode)) { onResolveMode(mode, choice) }
            .buttonBorderShape(.capsule)
    }

    private func timeConstraintButton(_ constraint: RouteTimeConstraint) -> some View {
        Button(constraint.buttonTitle) { onResolveTimeConflict(constraint) }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
    }
}

private extension RouteTimeConstraint {
    var buttonTitle: String {
        let prefix = meaning == .arrival ? "Arriver avant" : "Partir après"
        return "\(prefix) \(requestedAt.formatted(date: .omitted, time: .shortened))"
    }
}

private extension NaturalJourneyModeConstraint {
    func buttonTitle(for mode: TransitMode) -> String {
        switch self {
        case .required: "Utiliser \(mode.naturalLanguageNameWithArticle) uniquement"
        case .excluded: "Éviter \(mode.naturalLanguageNameWithArticle)"
        case .preferred: "Préférer \(mode.naturalLanguageNameWithArticle)"
        }
    }
}
