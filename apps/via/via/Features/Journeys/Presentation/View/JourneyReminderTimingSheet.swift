import SwiftUI
import UIKit

struct JourneyReminderTimingSheet: View {
  let isScheduled: Bool
  let authorizationDenied: Bool
  let onSave: @MainActor (JourneyNotificationPreferences.DepartureLeadTime) async -> String?
  let onCancel: @MainActor () async -> String?

  @State private var selectedLeadTime: JourneyNotificationPreferences.DepartureLeadTime
  @State private var isSubmitting = false
  @State private var errorMessage: String?
  @State private var isErrorPresented = false

  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  init(
    initialLeadTime: JourneyNotificationPreferences.DepartureLeadTime,
    isScheduled: Bool,
    authorizationDenied: Bool,
    onSave: @escaping @MainActor (JourneyNotificationPreferences.DepartureLeadTime) async -> String?,
    onCancel: @escaping @MainActor () async -> String?
  ) {
    self.isScheduled = isScheduled
    self.authorizationDenied = authorizationDenied
    self.onSave = onSave
    self.onCancel = onCancel
    _selectedLeadTime = State(initialValue: initialLeadTime)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          JourneyReminderTimingHeader()

          JourneyReminderMinutePicker(selection: $selectedLeadTime)

          JourneyReminderTimingActions(
            isScheduled: isScheduled,
            isSubmitting: isSubmitting,
            onSave: save,
            onCancel: cancel
          )
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle("Rappel de trajet")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(role: .close) {
            dismiss()
          }
          .disabled(isSubmitting)
        }
      }
    }
    .interactiveDismissDisabled(isSubmitting)
    // Success dismisses this sheet, and a view on its way out plays nothing:
    // the reminder itself reports back from the bar that owns the bell.
    .haptic(Haptic.failed, on: isErrorPresented) { !$0 && $1 }
    .alert("Rappel non modifié", isPresented: $isErrorPresented) {
      if authorizationDenied {
        Button("Ouvrir les réglages iOS", systemImage: "gearshape") {
          guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
          openURL(url)
        }
      }
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "Le rappel n’a pas pu être modifié.")
    }
  }

  private func save() {
    isSubmitting = true
    Task {
      if let message = await onSave(selectedLeadTime) {
        presentError(message)
      } else {
        dismiss()
      }
      isSubmitting = false
    }
  }

  private func cancel() {
    isSubmitting = true
    Task {
      if let message = await onCancel() {
        presentError(message)
      } else {
        dismiss()
      }
      isSubmitting = false
    }
  }

  private func presentError(_ message: String) {
    errorMessage = message
    isErrorPresented = true
  }
}
