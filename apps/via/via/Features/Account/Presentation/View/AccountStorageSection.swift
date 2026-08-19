import SwiftUI

struct AccountStorageSection: View {
    let account: AccountModel
    @Binding var isClearHistoryConfirmationPresented: Bool

    var body: some View {
        Section("Données") {
            NavigationLink {
                RecentSearchesView(account: account)
            } label: {
                Label("Historique des recherches", systemImage: "clock.arrow.circlepath")
            }

            AccountExportLink(export: account.makeExport())

            Button("Effacer l’historique", role: .destructive) {
                isClearHistoryConfirmationPresented = true
            }
        }
    }
}
