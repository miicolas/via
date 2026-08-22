import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    let accountModel: AccountModel
    let coordinator: NotificationScheduleCoordinator
    let inboxRemote: any NotificationInboxRemote
    let journeyNotificationCoordinator: JourneyNotificationCoordinator

    @Environment(\.openURL) private var openURL
    @State private var isNotificationAuthorizationRequested = false

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
                Button {
                    // Turning the master switch on is a request for notifications;
                    // iOS still has to be asked, and only the first ask ever prompts.
                    let willEnable = !accountModel.notificationPreferences.enabled
                    updatePreferences { $0.enabled.toggle() }
                    if willEnable { isNotificationAuthorizationRequested = true }
                } label: {
                    HStack(spacing: 12) {
                        SettingsRow(
                            title: "Notifications",
                            systemImage: accountModel.notificationPreferences.enabled
                                ? "bell.fill"
                                : "bell.slash.fill",
                            subtitle: accountModel.notificationPreferences.enabled
                                ? "Les alertes importantes sont activées"
                                : "Toutes les alertes sont désactivées",
                            tint: accountModel.notificationPreferences.enabled ? .orange : .secondary
                        )
                        Image(systemName: accountModel.notificationPreferences.enabled
                            ? "checkmark.circle.fill"
                            : "circle")
                            .foregroundStyle(accountModel.notificationPreferences.enabled ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notifications")
                .accessibilityValue(accountModel.notificationPreferences.enabled ? "Activées" : "Désactivées")
                .accessibilityAddTraits(.isToggle)

                authorizationRow

                if coordinator.authorizationStatus == .notDetermined {
                    NotificationAuthorizationButton {
                        await coordinator.restore()
                        await journeyNotificationCoordinator.refreshAuthorizationStatus()
                    }
                } else if !coordinator.isAuthorized {
                    EmptyStateView(.notificationsDenied) {
                        Button("Ouvrir les réglages iOS", systemImage: "gearshape") {
                            openURL.systemSettings()
                        }
                        .secondaryAction()
                    }
                }
            } header: {
                Text("ÉTAT")
            }

            Section {
                NavigationLink {
                    NotificationInboxView(remote: inboxRemote)
                } label: {
                    SettingsRow(
                        title: "Centre de notifications",
                        systemImage: "bell.badge",
                        subtitle: "Historique et alertes importantes",
                        value: inboxValue
                    )
                }

                NavigationLink {
                    NotificationScheduleListView(
                        accountModel: accountModel,
                        coordinator: coordinator
                    )
                } label: {
                    SettingsRow(
                        title: "Programmations",
                        systemImage: "calendar.badge.clock",
                        subtitle: "Rappels récurrents et résumés",
                        value: scheduleValue
                    )
                }

                NavigationLink {
                    JourneyNotificationsSettingsView(coordinator: journeyNotificationCoordinator)
                } label: {
                    SettingsRow(
                        title: "Trajet actif",
                        systemImage: "figure.walk.motion",
                        subtitle: "Départ, correspondances et arrivée"
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
                Text("À RECEVOIR")
            }

            Section {
                NotificationCategoryRow(
                    preference: preference(for: .journey),
                    onToggle: { toggleCategory(.journey) }
                )
                NotificationCategoryRow(
                    preference: preference(for: .commute),
                    onToggle: { toggleCategory(.commute) }
                )
                NotificationCategoryRow(
                    preference: preference(for: .line),
                    onToggle: { toggleCategory(.line) }
                )
                NotificationCategoryRow(
                    preference: preference(for: .station),
                    onToggle: { toggleCategory(.station) }
                )
                NotificationCategoryRow(
                    preference: preference(for: .digest),
                    onToggle: { toggleCategory(.digest) }
                )
                NotificationCategoryRow(
                    preference: preference(for: .recommendation),
                    onToggle: { toggleCategory(.recommendation) }
                )
            } header: {
                Text("CATÉGORIES")
            } footer: {
                Text("Vous pouvez désactiver une catégorie sans perdre vos programmations ni vos abonnements.")
            }

            Section {
                NavigationLink {
                    NotificationQuietHoursView(
                        preferences: accountModel.notificationPreferences,
                        onSave: { preferences in
                            accountModel.setNotificationPreferences(preferences)
                        }
                    )
                } label: {
                    SettingsRow(
                        title: "Heures calmes",
                        systemImage: "moon.fill",
                        subtitle: quietHoursSubtitle
                    )
                }

                Button {
                    updatePreferences { $0.mutedOnWeekends.toggle() }
                } label: {
                    preferenceButtonRow(
                        title: "Silencieux le week-end",
                        systemImage: "calendar",
                        enabled: accountModel.notificationPreferences.mutedOnWeekends
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Silencieux le week-end")
                .accessibilityValue(accountModel.notificationPreferences.mutedOnWeekends ? "Activé" : "Désactivé")
                .accessibilityAddTraits(.isToggle)

                Button {
                    updatePreferences { $0.mutedOnHolidays.toggle() }
                } label: {
                    preferenceButtonRow(
                        title: "Silencieux les jours fériés",
                        systemImage: "calendar.badge.exclamationmark",
                        enabled: accountModel.notificationPreferences.mutedOnHolidays
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Silencieux les jours fériés")
                .accessibilityValue(accountModel.notificationPreferences.mutedOnHolidays ? "Activé" : "Désactivé")
                .accessibilityAddTraits(.isToggle)

                Picker(
                    "Niveau minimum",
                    selection: Binding(
                        get: { accountModel.notificationPreferences.minimumSeverity },
                        set: { severity in updatePreferences { $0.minimumSeverity = severity } }
                    )
                ) {
                    ForEach(NotificationSeverity.allCases) { severity in
                        Text(severity.title).tag(severity)
                    }
                }
            } header: {
                Text("FILTRES")
            } footer: {
                Text("Les heures utilisent le fuseau Europe/Paris. Les perturbations suspendues restent prioritaires lorsqu’elles sont autorisées.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .notificationAuthorization(
            isRequested: $isNotificationAuthorizationRequested,
            message: "Autorisez les notifications dans Réglages iOS pour recevoir les alertes de Via."
        )
        .task { await coordinator.restore() }
        .task(id: reconciliationKey) {
            await coordinator.reconcile(
                schedules: accountModel.notificationSchedules,
                preferences: accountModel.notificationPreferences
            )
        }
    }

    private var authorizationRow: some View {
        HStack(spacing: 14) {
            Image(systemName: authorizationSystemImage)
                .foregroundStyle(authorizationColor)
                .frame(width: 26)
            Text("Autorisation iOS")
            Spacer()
            Text(authorizationTitle)
                .foregroundStyle(authorizationColor)
        }
        .frame(minHeight: 44)
    }

    private func preferenceButtonRow(
        title: String,
        systemImage: String,
        enabled: Bool
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(enabled ? .primary : .secondary)
                .frame(width: 32)
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(enabled ? .green : .secondary)
        }
        .frame(minHeight: 50)
        .contentShape(Rectangle())
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

    private var scheduleValue: String? {
        let count = accountModel.notificationSchedules.filter { $0.deletedAt == nil }.count
        return count == 0 ? nil : "\(count)"
    }

    private var alertValue: String? {
        let count = accountModel.notificationAlerts.filter { $0.deletedAt == nil && $0.enabled }.count
        return count == 0 ? nil : "\(count)"
    }

    private var inboxValue: String? {
        nil
    }

    private var quietHoursSubtitle: String {
        guard let start = accountModel.notificationPreferences.quietHoursStartMinute,
              let end = accountModel.notificationPreferences.quietHoursEndMinute else {
            return "Aucune plage"
        }
        return "\(formatMinute(start)) – \(formatMinute(end))"
    }

    private var reconciliationKey: String {
        String(
            describing: [
                accountModel.notificationPreferences,
                accountModel.notificationSchedules,
            ]
        )
    }

    private func preference(for category: NotificationCategory) -> NotificationCategoryPreference {
        accountModel.notificationPreferences.categories.first { $0.category == category }
            ?? NotificationCategoryPreference(
                category: category,
                enabled: true,
                minimumSeverity: .attention,
                dailyCap: nil
            )
    }

    private func toggleCategory(_ category: NotificationCategory) {
        updatePreferences { preferences in
            var categories = preferences.categories
            if let index = categories.firstIndex(where: { $0.category == category }) {
                categories[index].enabled.toggle()
            } else {
                categories.append(NotificationCategoryPreference(
                    category: category,
                    enabled: false,
                    minimumSeverity: .attention,
                    dailyCap: nil
                ))
            }
            preferences.categories = categories
        }
    }

    private func updatePreferences(_ update: (inout NotificationPreferences) -> Void) {
        var preferences = accountModel.notificationPreferences
        update(&preferences)
        preferences.updatedAt = .now
        accountModel.setNotificationPreferences(preferences)
    }

    private func formatMinute(_ minute: Int) -> String {
        let hour = minute / 60
        let value = minute % 60
        return String(format: "%02d:%02d", hour, value)
    }

}
