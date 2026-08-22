import SwiftUI

struct JourneyReminderTimingActions: View {
  let isScheduled: Bool
  let isSubmitting: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      Button(action: onSave) {
        HStack(spacing: 9) {
          if isSubmitting {
            ProgressView()
              .controlSize(.small)
              .tint(.white)
          }

          Label(
            isScheduled ? "Enregistrer le délai" : "Programmer le rappel",
            systemImage: "bell.badge.fill"
          )
        }
      }
      .primaryAction()
      .disabled(isSubmitting)

      if isScheduled {
        Button(role: .destructive, action: onCancel) {
          Label("Annuler le rappel", systemImage: "bell.slash")
        }
        .secondaryAction()
        .tint(.red)
        .disabled(isSubmitting)
      }
    }
  }
}
