import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    let accountModel: AccountModel
    let coordinator: NotificationScheduleCoordinator
    let inboxRemote: any NotificationInboxRemote
    let journeyNotificationCoordinator: JourneyNotificationCoordinator

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    init(
        accountModel: AccountModel,
        coordinator: NotificationScheduleCoordinator = .shared,
        inboxRemote: any NotificationInboxRemote = NoOpNotificationInboxRemote(),
        journeyNotificationCoordinator: JourneyNotificationCoordinator = .preview
    ) {
        self.accountModel = accountModel
        self.coordinator = coordinator
        self.inboxRemote = inboxRemote
        self.journeyNotificationCoordinator = journeyNotificationCoordinator
    }

    var body: some View {
        List {
            Section {
                SettingsRow(
                    title: "Notifications iOS",
                    systemImage: "bell.fill",
                    subtitle: "Sons et affichage gérés par iOS",
                    tint: authorizationColor,
                    value: authorizationTitle
                )

                if coordinator.authorizationStatus == .notDetermined {
                    NotificationAuthorizationButton {
                        await coordinator.restore()
                        await journeyNotificationCoordinator.refreshAuthorizationStatus()
                    }
                } else {
                    Button("Ouvrir les réglages iOS", systemImage: "gearshape") {
                        openURL.systemSettings()
                    }
                    .secondaryAction()
                }
            } header: {
                Text("AUTORISATION")
            } footer: {
                Text("L’activation, les sons et l’affichage des notifications se règlent uniquement dans Réglages iOS.")
            }

            Section {
                NavigationLink {
                    JourneyNotificationsSettingsView(coordinator: journeyNotificationCoordinator)
                } label: {
                    SettingsRow(
                        title: "Rappel de trajet",
                        systemImage: "figure.walk.motion",
                        subtitle: "Avant le départ d’un trajet actif",
                        value: journeyReminderValue
                    )
                }

                NavigationLink {
                    NotificationScheduleListView(
                        accountModel: accountModel,
                        coordinator: coordinator
                    )
                } label: {
                    SettingsRow(
                        title: "Rappels récurrents",
                        systemImage: "calendar.badge.clock",
                        subtitle: "Pour vos trajets habituels",
                        value: scheduleValue
                    )
                }

                NavigationLink {
                    NotificationAlertSubscriptionsView(accountModel: accountModel)
                } label: {
                    SettingsRow(
                        title: "Lignes et stations suivies",
                        systemImage: "tram.fill",
                        subtitle: "Perturbations et retours à la normale",
                        value: alertValue
                    )
                }
            } header: {
                Text("MES RAPPELS")
            } footer: {
                Text("Metyro vous prévient seulement pour les rappels et les suivis que vous avez choisis.")
            }

            Section {
                NavigationLink {
                    NotificationInboxView(remote: inboxRemote)
                } label: {
                    SettingsRow(
                        title: "Historique",
                        systemImage: "tray.full.fill",
                        subtitle: "Notifications reçues"
                    )
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await coordinator.restore()
            await journeyNotificationCoordinator.refreshAuthorizationStatus()
        }
        .task(id: reconciliationKey) {
            await coordinator.reconcile(
                schedules: accountModel.notificationSchedules,
                preferences: accountModel.notificationPreferences
            )
        }
    }

    private var authorizationTitle: String {
        switch coordinator.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "Autorisées"
        case .notDetermined: "À autoriser"
        case .denied: "Refusées"
        @unknown default: "À vérifier"
        }
    }

    private var authorizationColor: Color {
        switch coordinator.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .green
        case .denied: .orange
        default: .secondary
        }
    }

    private var scheduleValue: String? {
        let count = accountModel.notificationSchedules.filter { $0.deletedAt == nil }.count
        return count == 0 ? nil : "\(count)"
    }

    private var alertValue: String? {
        let count = accountModel.notificationAlerts.filter { $0.deletedAt == nil && $0.enabled }.count
        return count == 0 ? nil : "\(count)"
    }

    private var journeyReminderValue: String? {
        journeyNotificationCoordinator.reminder == nil ? nil : "Actif"
    }

    private var reconciliationKey: String {
        String(
            describing: [
                accountModel.notificationPreferences,
                accountModel.notificationSchedules,
            ]
        )
    }

}
