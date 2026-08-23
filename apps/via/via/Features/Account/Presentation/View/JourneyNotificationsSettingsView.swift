import SwiftUI

struct JourneyNotificationsSettingsView: View {
    let coordinator: JourneyNotificationCoordinator

    var body: some View {
        List {
            Section {
                Picker(
                    "Délai avant le départ",
                    selection: Binding(
                        get: { coordinator.preferences.departureLeadTime },
                        set: { leadTime in
                            Task { await coordinator.updateDepartureLeadTime(leadTime) }
                        }
                    )
                ) {
                    ForEach(JourneyNotificationPreferences.DepartureLeadTime.allCases) { leadTime in
                        Text(leadTime.title).tag(leadTime)
                    }
                }
                .accessibilityLabel("Délai avant le départ")
            } header: {
                Text("RAPPELS DE TRAJET")
            } footer: {
                Text("Le rappel utilise les horaires du trajet mémorisé et fonctionne même hors ligne. Un seul trajet peut être programmé à la fois.")
            }

            if let reminder = coordinator.reminder {
                Section("TRAJET PROGRAMMÉ") {
                    LabeledContent("Destination", value: reminder.destination.name)
                    Button("Annuler le rappel", systemImage: "bell.slash") {
                        Task { await coordinator.cancelReminder() }
                    }
                    .secondaryAction()
                }
            }
        }
        .navigationTitle("Rappels de trajet")
        .toolbarTitleDisplayMode(.inlineLarge)
        .task { await coordinator.restore() }
    }
}
