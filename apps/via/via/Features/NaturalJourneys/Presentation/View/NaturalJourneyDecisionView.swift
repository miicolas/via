import SwiftUI

struct NaturalJourneyDecisionView: View {
    let decision: NaturalJourneyDecision
    let onConfirmCurrentLocation: () -> Void
    let onResolveMode: (TransitMode, NaturalJourneyModeConstraint) -> Void
    let onContinueWithoutUnsupported: () -> Void
    let onResolveTimeConflict: (RouteTimeConstraint) -> Void
    let onModify: () -> Void

    var body: some View {
        NaturalJourneyStateCard(title: decision.title, systemImage: decision.systemImage) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch decision {
        case .currentLocation:
            Text("Aucune origine n’est indiquée. Veux-tu partir de ta position actuelle ?")
                .naturalJourneyMessage()
            Button("Utiliser ma position", systemImage: "location.fill", action: onConfirmCurrentLocation)
                .naturalJourneyPrimaryAction()
            Button("Indiquer une autre origine", action: onModify)
                .naturalJourneySecondaryAction()

        case let .modeConflict(mode, choices):
            Text("Deux contraintes se contredisent pour \(mode.naturalLanguageNameWithArticle). Laquelle veux-tu conserver ?")
                .naturalJourneyMessage()
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                if index == 0 {
                    modeChoiceButton(choice, mode: mode)
                        .naturalJourneyPrimaryAction()
                } else {
                    modeChoiceButton(choice, mode: mode)
                        .naturalJourneySecondaryAction()
                }
            }

        case let .unsupportedConstraints(constraints):
            Text(constraints.joined(separator: " · "))
                .font(.headline)
            Text("Via ne sait pas encore appliquer cette contrainte.")
                .naturalJourneyMessage()
            Button("Continuer sans cette contrainte", action: onContinueWithoutUnsupported)
                .naturalJourneyPrimaryAction()
            Button("Modifier la demande", action: onModify)
                .naturalJourneySecondaryAction()

        case let .pastDate(date):
            Text(JourneyFormatting.dateTime(date))
                .font(.headline)
            Text("La date était explicite, Via ne la déplacera pas silencieusement.")
                .naturalJourneyMessage()
            Button("Modifier la demande", action: onModify)
                .naturalJourneyPrimaryAction()

        case let .timeConflict(first, second):
            Text("Le moteur accepte une heure de départ ou une heure d’arrivée.")
                .naturalJourneyMessage()
            timeConstraintButton(first)
            timeConstraintButton(second)
        }
    }

    private func modeChoiceButton(
        _ choice: NaturalJourneyModeConstraint,
        mode: TransitMode,
    ) -> some View {
        Button(choice.buttonTitle(for: mode)) { onResolveMode(mode, choice) }
    }

    private func timeConstraintButton(_ constraint: RouteTimeConstraint) -> some View {
        Button(constraint.buttonTitle) { onResolveTimeConflict(constraint) }
            .naturalJourneyPrimaryAction()
    }
}

private extension NaturalJourneyDecision {
    var title: String {
        switch self {
        case .currentLocation: "Choisir le départ"
        case .modeConflict: "Contraintes contradictoires"
        case .unsupportedConstraints: "Contrainte indisponible"
        case .pastDate: "Cette heure est passée"
        case .timeConflict: "Choisis la contrainte horaire"
        }
    }

    var systemImage: String {
        switch self {
        case .currentLocation: "location.circle"
        case .modeConflict: "arrow.trianglehead.branch"
        case .unsupportedConstraints: "exclamationmark.triangle"
        case .pastDate: "clock.badge.exclamationmark"
        case .timeConflict: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
        }
    }
}

private extension RouteTimeConstraint {
    var buttonTitle: String {
        let prefix = meaning == .arrival ? "Arriver avant" : "Partir après"
        return "\(prefix) \(JourneyFormatting.time(requestedAt))"
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
