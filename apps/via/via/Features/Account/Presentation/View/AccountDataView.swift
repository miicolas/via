import SwiftUI

struct AccountDataView: View {
    let account: AccountModel
    let authSession: AuthSessionViewModel
    let onboarding: OnboardingModel

    @State private var isClearHistoryConfirmationPresented = false
    @State private var isResetPreferencesConfirmationPresented = false
    @State private var isEraseDeviceConfirmationPresented = false
    @State private var isDeleteAccountConfirmationPresented = false
    @State private var isAppleReauthorizationPresented = false

    var body: some View {
        List {
            AccountSynchronizationSection(
                state: account.syncState,
                isSignedIn: authSession.isSignedIn,
                onSynchronize: account.synchronize
            )
            AccountStorageSection(
                account: account,
                isClearHistoryConfirmationPresented: $isClearHistoryConfirmationPresented
            )
            AccountIdentitySection(
                session: authSession.session,
                isDeleteAccountConfirmationPresented: $isDeleteAccountConfirmationPresented,
                onSignOut: {
                    Task { await authSession.signOut() }
                }
            )
            AccountResetSection(
                isResetPreferencesConfirmationPresented: $isResetPreferencesConfirmationPresented,
                isEraseDeviceConfirmationPresented: $isEraseDeviceConfirmationPresented
            )
            AccountAuthenticationErrorSection(message: authSession.errorMessage)
        }
        .navigationTitle("Compte et données")
        .toolbarTitleDisplayMode(.inlineLarge)
        .confirmationDialog(
            "Effacer l’historique ?",
            isPresented: $isClearHistoryConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Effacer l’historique", role: .destructive) {
                account.clearRecentSearches()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est irréversible sur les espaces actuellement utilisés.")
        }
        .confirmationDialog(
            "Réinitialiser les préférences ?",
            isPresented: $isResetPreferencesConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Réinitialiser", role: .destructive) {
                account.resetPreferences()
                onboarding.reset()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les modes et l’introduction seront réinitialisés. Les favoris, lieux et l’historique resteront en place.")
        }
        .confirmationDialog(
            "Effacer les données de cet appareil ?",
            isPresented: $isEraseDeviceConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Effacer cet appareil", role: .destructive) {
                Task { await authSession.eraseDeviceData() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Seule la copie locale sera supprimée. Le compte distant restera intact.")
        }
        .confirmationDialog(
            "Supprimer le compte Via ?",
            isPresented: $isDeleteAccountConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Continuer avec Apple", role: .destructive) {
                isAppleReauthorizationPresented = true
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action supprime le compte distant et ses données synchronisées. Une confirmation Apple récente est requise.")
        }
        .sheet(isPresented: $isAppleReauthorizationPresented) {
            AccountDeletionSheet(
                isDeletingAccount: authSession.isDeletingAccount,
                onOutcome: { outcome in
                    Task {
                        await authSession.completeAccountDeletion(outcome)
                        isAppleReauthorizationPresented = false
                    }
                },
                onCancel: {
                    isAppleReauthorizationPresented = false
                }
            )
        }
    }
}
