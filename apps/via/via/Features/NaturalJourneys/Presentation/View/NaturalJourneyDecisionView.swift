import SwiftUI

struct NaturalJourneyDecisionView: View {
    let decision: NaturalJourneyDecision
    let onConfirmCurrentLocation: () -> Void
    let onResolveMode: (TransitMode, NaturalJourneyModeConstraint) -> Void
    let onContinueWithoutUnsupported: () -> Void
    let onResolveTimeConflict: (RouteTimeConstraint) -> Void
    let onModify: () -> Void

    var body: some View {
        NaturalJourneyStateCard(
            systemImage: decision.systemImage,
            title: decision.title,
            message: decision.message,
        ) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch decision {
        case .currentLocation:
            Button("Utiliser ma position", systemImage: "location.fill", action: onConfirmCurrentLocation)
                .naturalJourneyPrimaryAction()
            Button("Indiquer une autre origine", action: onModify)
                .naturalJourneySecondaryAction()

        case let .modeConflict(mode, choices):
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
            highlight(constraints.joined(separator: " · "))
            Button("Continuer sans cette contrainte", action: onContinueWithoutUnsupported)
                .naturalJourneyPrimaryAction()
            Button("Modifier la demande", action: onModify)
                .naturalJourneySecondaryAction()

        case let .pastDate(date):
            highlight(JourneyFormatting.dateTime(date))
            Button("Modifier la demande", systemImage: "pencil", action: onModify)
                .naturalJourneyPrimaryAction()

        case let .timeConflict(first, second):
            timeConstraintButton(first)
                .naturalJourneyPrimaryAction()
            timeConstraintButton(second)
                .naturalJourneySecondaryAction()
        }
    }

    /// The fragment of the request the decision is actually about, set apart so
    /// the traveller can check it against what they typed.
    private func highlight(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(Color.aiSurface), in: .capsule)
    }

    private func modeChoiceButton(
        _ choice: NaturalJourneyModeConstraint,
        mode: TransitMode,
    ) -> some View {
        Button(choice.buttonTitle(for: mode)) { onResolveMode(mode, choice) }
    }

    private func timeConstraintButton(_ constraint: RouteTimeConstraint) -> some View {
        Button(constraint.buttonTitle) { onResolveTimeConflict(constraint) }
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

    var message: String {
        switch self {
        case .currentLocation:
            "Aucune origine n’est indiquée. Veux-tu partir de ta position actuelle ?"
        case let .modeConflict(mode, _):
            "Deux contraintes se contredisent pour \(mode.naturalLanguageNameWithArticle). Laquelle veux-tu conserver ?"
        case .unsupportedConstraints:
            "Via ne sait pas encore appliquer cette contrainte."
        case .pastDate:
            "La date était explicite, Via ne la déplacera pas silencieusement."
        case .timeConflict:
            "Le moteur accepte une heure de départ ou une heure d’arrivée."
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
