import SwiftUI

struct NaturalJourneyDecisionView: View {
    let decision: NaturalJourneyDecision
    let onConfirmCurrentLocation: () -> Void
    let onResolveInterpretationConflict: () -> Void
    let onContinueAfterUnexplainedText: () -> Void
    let onChooseMissingSavedPlace: (
        NaturalJourneyClarification.Target,
        NaturalJourneySavedPlaceKind,
        Bool
    ) -> Void
    let onResolveMode: (TransitMode, NaturalJourneyModeConstraint) -> Void
    let onContinueWithoutUnsupported: () -> Void
    let onResolveTimeConflict: (RouteTimeConstraint) -> Void
    let onModify: () -> Void

    var body: some View {
        EmptyStateView(
            .ai(
                systemImage: decision.systemImage,
                title: decision.title,
                message: decision.message,
            ),
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

        case let .interpretationConflict(fields):
            highlight(fields.map(\.displayName).joined(separator: " · "))
            Button(
                "Préciser la demande",
                systemImage: "text.cursor",
                action: onResolveInterpretationConflict,
            )
            .naturalJourneyPrimaryAction()

        case let .unexplainedText(text):
            highlight(text)
            Button(
                "Continuer sans ce fragment",
                systemImage: "arrow.right",
                action: onContinueAfterUnexplainedText,
            )
            .naturalJourneyPrimaryAction()
            Button("Modifier la demande", systemImage: "pencil", action: onModify)
                .naturalJourneySecondaryAction()

        case let .missingSavedPlace(target, kind):
            Button("Choisir pour cette fois", systemImage: "mappin.and.ellipse") {
                onChooseMissingSavedPlace(target, kind, false)
            }
            .naturalJourneyPrimaryAction()
            if kind != .custom {
                Button(
                    kind == .home ? "Choisir et enregistrer Maison" : "Choisir et enregistrer Travail",
                    systemImage: kind == .home ? "house.fill" : "briefcase.fill",
                ) {
                    onChooseMissingSavedPlace(target, kind, true)
                }
                .naturalJourneySecondaryAction()
            }

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
        case .interpretationConflict: "Demande contradictoire"
        case .unexplainedText: "Un fragment reste incertain"
        case let .missingSavedPlace(_, kind): kind.missingTitle
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
        case .interpretationConflict:
            "Deux interprétations restent plausibles. Via ne choisira ni n’inversera le trajet silencieusement."
        case .unexplainedText:
            "Via a compris le trajet, mais pas ce fragment. Tu peux l’ignorer explicitement ou le reformuler."
        case let .missingSavedPlace(_, kind):
            "« \(kind.personalName) » n’est pas encore associé à un lieu. Choisis-le pour cette recherche ou enregistre-le pour les suivantes."
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
        case .interpretationConflict: "arrow.left.arrow.right.circle"
        case .unexplainedText: "text.badge.questionmark"
        case let .missingSavedPlace(_, kind): kind.systemImage
        case .modeConflict: "arrow.trianglehead.branch"
        case .unsupportedConstraints: "exclamationmark.triangle"
        case .pastDate: "clock.badge.exclamationmark"
        case .timeConflict: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
        }
    }
}

private extension NaturalJourneyIntentField {
    var displayName: String {
        switch self {
        case .scope: "type de demande"
        case .origin: "départ"
        case .destination: "destination"
        case .time: "heure"
        case .modes: "modes"
        case .unsupportedConstraints: "contraintes"
        }
    }
}

private extension NaturalJourneySavedPlaceKind {
    var personalName: String {
        switch self {
        case .home: "Maison"
        case .work: "Travail"
        case .custom: "ce lieu"
        }
    }

    var missingTitle: String { "Configurer \(personalName)" }

    var systemImage: String {
        switch self {
        case .home: "house.circle"
        case .work: "briefcase.circle"
        case .custom: "mappin.circle"
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
