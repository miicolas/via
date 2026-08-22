import SwiftUI

struct NotificationScheduleRow: View {
    let schedule: NotificationSchedule

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: schedule.kind == .commute ? "calendar.badge.clock" : "text.badge.checkmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(schedule.enabled ? .orange : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.label)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if !schedule.enabled {
                Image(systemName: "pause.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("En pause")
            }
        }
        .frame(minHeight: 52)
    }

    private var detail: String {
        let hour = schedule.departureMinute / 60
        let minute = schedule.departureMinute % 60
        let days = schedule.daysOfWeek.isEmpty ? "Tous les jours" : schedule.daysOfWeek.map(Self.shortDay).joined(separator: ", ")
        let formatted = String(format: "%02d:%02d", hour, minute)
        return "\(formatted) · \(days)"
    }

    private static func shortDay(_ day: Int) -> String {
        switch day {
        case 0: "Dim"
        case 1: "Lun"
        case 2: "Mar"
        case 3: "Mer"
        case 4: "Jeu"
        case 5: "Ven"
        case 6: "Sam"
        default: ""
        }
    }
}
