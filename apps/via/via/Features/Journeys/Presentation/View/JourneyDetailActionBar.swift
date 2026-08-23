import SwiftUI

/// The two things a planned journey offers: start it, or be reminded. Starting
/// it is the screen's `primaryAction`, so it keeps its verb — the one place
/// Via lets a control carry words. The reminder rides beside it as a round
/// state glyph, its wording living in the accessibility label.
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
            Label {
              Text(action.title)
                .font(.headline)
            } icon: {
              if isActivating {
                ProgressView()
                  .controlSize(.small)
                  .tint(.white)
              } else {
                Image(systemName: action.systemImage)
                  .stateSymbolTransition(value: action)
              }
            }
          }
          .primaryAction()
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
            isUpdatingReminder ? "Mise à jour" : (isReminderScheduled ? "Activé" : "Désactivé")
          )
          .accessibilityHint("Ouvre le réglage du délai avant le départ")
        }
      }
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
