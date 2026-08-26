import SwiftUI

/// A single unmistakable journey action with the reminder kept as a secondary
/// icon. Starting a journey uses Via blue; resuming a live journey keeps the
/// green live-state cue while preserving the full-width primary action.
struct JourneyDetailActionBar: View {
    let isActivating: Bool
    let isReminderScheduled: Bool
    let isUpdatingReminder: Bool
    let actionAt: (Date) -> JourneyActivationAction
    let onAction: (JourneyActivationAction) -> Void
    let onReminder: () -> Void

    @State private var actionTick = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let action = actionAt(context.date)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        actionTick += 1
                        onAction(action)
                    } label: {
                        HStack(spacing: 9) {
                            if isActivating {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }

                            Text(action.displayTitle)
                                .font(.headline)
                        }
                    }
                    .primaryAction(tint: tint(for: action))
                    .disabled(isActivating || action == .active || action == .planned)
                    // The single most consequential tap in Via. What follows is
                    // an alert or a spinner, so the decision is acknowledged
                    // here rather than left to whatever lands next.
                    .haptic(Haptic.commit, on: actionTick)
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
                    .toggleHaptic(on: isReminderScheduled)
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

    private func tint(for action: JourneyActivationAction) -> Color? {
        switch action {
        case .go: .blue
        case .resume: .green
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
