import SwiftUI

struct NotificationScheduleEditorView: View {
    let accountModel: AccountModel
    let coordinator: NotificationScheduleCoordinator
    let existingSchedule: NotificationSchedule?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: NotificationSchedule
    @State private var departureTime: Date

    init(
        accountModel: AccountModel,
        coordinator: NotificationScheduleCoordinator,
        schedule: NotificationSchedule?
    ) {
        self.accountModel = accountModel
        self.coordinator = coordinator
        existingSchedule = schedule
        let value = schedule ?? Self.newSchedule()
        _draft = State(initialValue: value)
        _departureTime = State(initialValue: Self.date(for: value.departureMinute))
    }

    var body: some View {
        List {
            Section("PROGRAMMATION") {
                TextField("Nom", text: $draft.label)

                DatePicker(
                    "Heure de départ",
                    selection: $departureTime,
                    displayedComponents: .hourAndMinute
                )

                Picker("Rappel", selection: $draft.leadMinutes) {
                    ForEach([0, 5, 10, 15, 30], id: \.self) { minutes in
                        Text(minutes == 0 ? "À l’heure" : "\(minutes) min avant")
                            .tag(minutes)
                    }
                }
            }

            Section("JOURS") {
                weekdaySelector
                Button {
                    draft.skipHolidays.toggle()
                } label: {
                    HStack {
                        SettingsRow(
                            title: "Ignorer les jours fériés",
                            systemImage: "calendar.badge.exclamationmark",
                            subtitle: "Aucune programmation les jours fériés"
                        )
                        Image(systemName: draft.skipHolidays ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(draft.skipHolidays ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ignorer les jours fériés")
                .accessibilityValue(draft.skipHolidays ? "Activé" : "Désactivé")
                .accessibilityAddTraits(.isToggle)
            }

            Section {
                Button("Enregistrer", systemImage: "checkmark") {
                    save()
                }
                .primaryAction()

                if existingSchedule != nil {
                    Button("Supprimer la programmation", systemImage: "trash", role: .destructive) {
                        accountModel.removeNotificationSchedule(id: draft.id)
                        dismiss()
                    }
                    .secondaryAction()
                }
            }
        }
        .navigationTitle(existingSchedule == nil ? "Nouvelle programmation" : "Modifier la programmation")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) { dismiss() }
            }
        }
    }

    private var weekdaySelector: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { day in
                let selected = draft.daysOfWeek.contains(day)
                Button {
                    if selected {
                        draft.daysOfWeek.removeAll { $0 == day }
                    } else {
                        draft.daysOfWeek.append(day)
                        draft.daysOfWeek.sort()
                    }
                } label: {
                    Text(Self.shortDay(day))
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(selected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.longDay(day))
                .accessibilityValue(selected ? "Sélectionné" : "Non sélectionné")
                .accessibilityAddTraits(.isToggle)
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        guard !draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        coordinator.unmute(scheduleID: draft.id)
        draft.departureMinute = Self.minute(from: departureTime)
        draft.updatedAt = .now
        draft.revision = max(1, draft.revision + (existingSchedule == nil ? 0 : 1))
        accountModel.saveNotificationSchedule(draft)
        dismiss()
    }

    private static func newSchedule() -> NotificationSchedule {
        let now = Date.now
        return NotificationSchedule(
            id: UUID().uuidString.lowercased(),
            kind: .commute,
            label: "Trajet domicile–travail",
            revision: 1,
            origin: nil,
            destination: nil,
            routeIDs: [],
            daysOfWeek: [1, 2, 3, 4, 5],
            departureMinute: 8 * 60,
            leadMinutes: 10,
            skipHolidays: true,
            enabled: true,
            pausedUntil: nil,
            timeZone: "Europe/Paris",
            savedAt: now,
            updatedAt: now,
            deletedAt: nil
        )
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

    private static func shortDay(_ day: Int) -> String {
        switch day {
        case 0: "D"
        case 1: "L"
        case 2: "M"
        case 3: "M"
        case 4: "J"
        case 5: "V"
        case 6: "S"
        default: "?"
        }
    }

    private static func longDay(_ day: Int) -> String {
        switch day {
        case 0: "Dimanche"
        case 1: "Lundi"
        case 2: "Mardi"
        case 3: "Mercredi"
        case 4: "Jeudi"
        case 5: "Vendredi"
        case 6: "Samedi"
        default: "Jour"
        }
    }
}
