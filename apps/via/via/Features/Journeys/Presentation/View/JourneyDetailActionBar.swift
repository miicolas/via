import SwiftUI

struct JourneyDetailActionBar: View {
  let isActivating: Bool
  let isReminderScheduled: Bool
  let isUpdatingReminder: Bool
  let actionAt: (Date) -> JourneyActivationAction
  let onAction: (JourneyActivationAction) -> Void
  let onReminder: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { context in
      let action = actionAt(context.date)

      VStack(spacing: 10) {
        Button {
          onAction(action)
        } label: {
          HStack(spacing: 9) {
            if isActivating {
              ProgressView()
                .controlSize(.small)
                .tint(.white)
            } else {
              Image(systemName: action.systemImage)
                .contentTransition(
                  reduceMotion
                    ? .identity
                    : .symbolEffect(
                      .replace.magic(fallback: .offUp.byLayer),
                      options: .nonRepeating
                    )
                )
                .animation(reduceMotion ? nil : .default, value: action)
            }

            Text(action.title)
              .font(.headline)
          }
        }
        .primaryAction()
        .disabled(isActivating || action == .active)
        .accessibilityHint(
          action == .active
            ? "Ce trajet est déjà actif"
            : "Active le guidage étape par étape dans Metyro"
        )

        Button(action: onReminder) {
          Label {
            Text(isReminderScheduled ? "Rappel programmé" : "Me rappeler")
          } icon: {
            Image(systemName: isReminderScheduled ? "bell.fill" : "bell")
              .contentTransition(
                reduceMotion
                  ? .identity
                  : .symbolEffect(
                    .replace.magic(fallback: .offUp.byLayer),
                    options: .nonRepeating
                  )
              )
              .animation(reduceMotion ? nil : .default, value: isReminderScheduled)
          }
          .font(.headline)
        }
        .secondaryAction()
        .disabled(isUpdatingReminder)
        .accessibilityValue(isReminderScheduled ? "Activé" : "Désactivé")
        .accessibilityHint("Ouvre le réglage du délai avant le départ")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(.bar)
    }
  }
}

private extension JourneyActivationAction {
  var systemImage: String {
    switch self {
    case .go: "location.fill"
    case .activate: "play.fill"
    case .resume: "arrow.clockwise"
    case .active: "checkmark"
    }
  }
}
