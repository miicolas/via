import SwiftUI

struct NotificationQuietHoursView: View {
    let preferences: NotificationPreferences
    let onSave: (NotificationPreferences) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isEnabled: Bool
    @State private var start: Date
    @State private var end: Date

    init(
        preferences: NotificationPreferences,
        onSave: @escaping (NotificationPreferences) -> Void
    ) {
        self.preferences = preferences
        self.onSave = onSave
        _isEnabled = State(initialValue: preferences.quietHoursStartMinute != nil && preferences.quietHoursEndMinute != nil)
        _start = State(initialValue: Self.date(for: preferences.quietHoursStartMinute ?? (22 * 60)))
        _end = State(initialValue: Self.date(for: preferences.quietHoursEndMinute ?? (7 * 60)))
    }

    var body: some View {
        List {
            Section {
                Button {
                    isEnabled.toggle()
                } label: {
                    HStack {
                        SettingsRow(
                            title: "Heures calmes",
                            systemImage: isEnabled ? "moon.fill" : "moon",
                            subtitle: isEnabled ? "Les alertes sont suspendues pendant cette plage" : "Aucune plage active"
                        )
                        Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isEnabled ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Heures calmes")
                .accessibilityValue(isEnabled ? "Activées" : "Désactivées")
                .accessibilityAddTraits(.isToggle)
            }

            if isEnabled {
                Section("PLAGE HORAIRE") {
                    DatePicker(
                        "Début",
                        selection: $start,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "Fin",
                        selection: $end,
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            Section {
                Button("Enregistrer", systemImage: "checkmark") {
                    var result = preferences
                    result.quietHoursStartMinute = isEnabled ? Self.minute(from: start) : nil
                    result.quietHoursEndMinute = isEnabled ? Self.minute(from: end) : nil
                    result.updatedAt = .now
                    onSave(result)
                    dismiss()
                }
                .primaryAction()
            }
        }
        .navigationTitle("Heures calmes")
        .navigationBarTitleDisplayMode(.large)
    }

    private static func date(for minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2_000
        components.month = 1
        components.day = 1
        components.hour = minute / 60
        components.minute = minute % 60
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }

    private static func minute(from date: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
}
