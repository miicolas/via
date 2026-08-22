import SwiftUI

struct NotificationAlertSubscriptionsView: View {
    let accountModel: AccountModel

    var body: some View {
        List {
            let alerts = accountModel.notificationAlerts.filter { $0.deletedAt == nil }
            if alerts.isEmpty {
                EmptyStateView(.noFollowedLines) {
                    Text("Ouvrez une fiche de ligne ou de station pour commencer un suivi.")
                        .emptyStateHint()
                }
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(alerts) { alert in
                        NotificationAlertSubscriptionRow(alert: alert)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    accountModel.removeNotificationAlert(id: alert.id)
                                } label: {
                                    Label("Ne plus suivre", systemImage: "bell.slash")
                                }
                            }
                    }
                } footer: {
                    Text("Les alertes apparaissent uniquement pendant les jours et les plages que vous avez autorisés.")
                }
            }
        }
        .navigationTitle("Lignes et stations suivies")
        .navigationBarTitleDisplayMode(.large)
    }
}
