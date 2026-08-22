import SwiftUI
import UserNotifications

struct JourneyNotificationsSettingsView: View {
    let coordinator: JourneyNotificationCoordinator

    @Environment(\.openURL) private var openURL

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

            Section {
                HStack(spacing: 14) {
                    Image(systemName: authorizationSystemImage)
                        .foregroundStyle(authorizationColor)
                        .frame(width: 26)
                    Text("Notifications")
                    Spacer()
                    Text(authorizationTitle)
                        .foregroundStyle(authorizationColor)
                }
                .frame(minHeight: 44)

                if coordinator.authorizationStatus == .notDetermined {
                    NotificationAuthorizationButton {
                        await coordinator.requestAuthorization()
                    }
                }

                if coordinator.authorizationStatus == .denied ||
                    (coordinator.lastError != nil && !coordinator.isAuthorized) {
                    Button("Ouvrir les réglages iOS", systemImage: "gearshape") {
                        openURL.systemSettings()
                    }
                    .secondaryAction()
                }
            } header: {
                Text("AUTORISATION")
            } footer: {
                Text("Si l’autorisation est refusée, votre intention de rappel reste mémorisée et sera reprise après activation dans Réglages iOS.")
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

    private var authorizationTitle: String {
        switch coordinator.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "Autorisé"
        case .notDetermined: "Non demandé"
        case .denied: "Refusé"
        @unknown default: "À vérifier"
        }
    }

    private var authorizationSystemImage: String {
        switch coordinator.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "bell.fill"
        case .denied: "bell.slash.fill"
        default: "bell"
        }
    }

    private var authorizationColor: Color {
        switch coordinator.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .green
        case .denied: .orange
        default: .secondary
        }
    }
}
