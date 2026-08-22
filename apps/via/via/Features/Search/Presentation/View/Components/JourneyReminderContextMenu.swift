import SwiftUI

struct JourneyReminderContextMenu: View {
  let selectedLeadTime: JourneyNotificationPreferences.DepartureLeadTime
  let isScheduled: Bool
  let isUpdating: Bool
  let onSchedule: (JourneyNotificationPreferences.DepartureLeadTime) -> Void
  let onCancel: () -> Void

  var body: some View {
    ForEach(JourneyNotificationPreferences.DepartureLeadTime.allCases) { leadTime in
      Button(
        "\(leadTime.rawValue) min avant le départ",
        systemImage: isScheduled && leadTime == selectedLeadTime ? "bell.fill" : "bell"
      ) {
        onSchedule(leadTime)
      }
      .disabled(isUpdating)
    }

    if isScheduled {
      Divider()

      Button("Annuler le rappel", systemImage: "bell.slash", role: .destructive) {
        onCancel()
      }
      .disabled(isUpdating)
    }
  }
}
