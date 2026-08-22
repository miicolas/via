import SwiftUI

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
          GlyphActionButton(
            systemImage: action.systemImage,
            isProminent: true,
            isBusy: isActivating,
            value: action,
            action: { onAction(action) }
          )
          .disabled(isActivating || action == .active)
          .accessibilityLabel(action.title)
          .accessibilityHint(
            action == .active
              ? "Ce trajet est déjà actif"
              : "Active le guidage étape par étape dans Metyro"
          )

          GlyphActionButton(
            systemImage: StateSymbol.bell(isOn: isReminderScheduled),
            isBusy: isUpdatingReminder,
            value: isReminderScheduled,
            action: onReminder
          )
          .disabled(isUpdatingReminder)
          .accessibilityLabel(isReminderScheduled ? "Rappel programmé" : "Me rappeler")
          .accessibilityValue(
            isUpdatingReminder ? "Mise à jour" : (isReminderScheduled ? "Activé" : "Désactivé")
          )
          .accessibilityHint("Ouvre le réglage du délai avant le départ")
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(.bar)
    }
  }
}

extension JourneyActivationAction {
  var systemImage: String {
    switch self {
    case .go: "location.fill"
    case .activate: "play.fill"
    case .resume: "arrow.clockwise"
    case .active: "checkmark"
    }
  }
}
