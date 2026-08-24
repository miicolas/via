import SwiftUI

/// A single unmistakable journey action with the reminder kept as a secondary
/// icon. Starting or resuming a live journey uses green, matching the reference
/// while preserving Via's full-width primary-action behavior.
struct JourneyDetailActionBar: View {
    let isActivating: Bool
    let isReminderScheduled: Bool
    let isUpdatingReminder: Bool
    let actionAt: (Date) -> JourneyActivationAction
    let onAction: (JourneyActivationAction) -> Void
    let onReminder: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let action = actionAt(context.date)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        onAction(action)
                    } label: {
                        HStack(spacing: 9) {
                            if isActivating {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }

                            Text(buttonTitle(for: action))
                                .font(.headline)
                        }
                    }
                    .primaryAction(tint: tint(for: action))
                    .disabled(isActivating || action == .active || action == .planned)
                    .accessibilityHint(action.accessibilityHint)

                    Button(action: onReminder) {
                        Label {
                            Text(isReminderScheduled ? "Rappel programmé" : "Me rappeler")
                        } icon: {
                            if isUpdatingReminder {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: StateSymbol.bell(isOn: isReminderScheduled))
                                    .stateSymbolTransition(value: isReminderScheduled)
                            }
                        }
                    }
                    .iconAction()
                    .disabled(isUpdatingReminder)
                    .accessibilityValue(
                        isUpdatingReminder
                            ? "Mise à jour"
                            : (isReminderScheduled ? "Activé" : "Désactivé")
                    )
                    .accessibilityHint("Ouvre le réglage du délai avant le départ")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private func buttonTitle(for action: JourneyActivationAction) -> String {
        action == .go ? "GO" : action.title
    }

    private func tint(for action: JourneyActivationAction) -> Color? {
        switch action {
        case .go, .resume: .green
        case .plan, .planned, .active: nil
        }
    }
}

extension JourneyActivationAction {
    var systemImage: String {
        switch self {
        case .go: "location.fill"
        case .plan: "calendar.badge.plus"
        case .planned: "calendar.badge.checkmark"
        case .resume: "arrow.clockwise"
        case .active: "checkmark"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .go:
            "Lance le guidage étape par étape dans Metyro"
        case .plan:
            "Enregistre ce trajet pour pouvoir le lancer rapidement plus tard"
        case .planned:
            "Ce trajet est déjà prévu"
        case .resume:
            "Reprend le guidage de ce trajet"
        case .active:
            "Ce trajet est déjà actif"
        }
    }
}
