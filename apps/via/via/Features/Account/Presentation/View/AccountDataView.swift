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
            Section("Synchronisation") {
                HStack {
                    SyncStatusLabel(state: account.syncState)
                    Spacer()
                    if account.syncState == .syncing {
                        ProgressView()
                    }
                }
                .frame(minHeight: 44)

                Button {
                    account.synchronize()
                } label: {
                    Label("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!authSession.isSignedIn)

                if case .failed(let error) = account.syncState {
                    Text(message(for: error))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Données") {
                NavigationLink {
                    RecentSearchesView(account: account)
                } label: {
                    Label("Historique des recherches", systemImage: "clock.arrow.circlepath")
                }

                ShareLink(item: account.makeExport()) {
                    Label("Exporter mes données", systemImage: "square.and.arrow.up")
                }

                Button("Effacer l’historique", role: .destructive) {
                    isClearHistoryConfirmationPresented = true
                }
            }

            if let session = authSession.session {
                Section("Compte Apple") {
                    LabeledContent("Nom", value: session.user.displayName)
                    LabeledContent("E-mail", value: session.user.email)

                    Button("Se déconnecter", role: .destructive) {
                        Task { await authSession.signOut() }
                    }

                    Button("Supprimer le compte", role: .destructive) {
                        isDeleteAccountConfirmationPresented = true
                    }
                }
            } else {
                Section {
                    Text("Les données de cet appareil restent disponibles sans compte.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Espace local")
                }
            }

            Section("Réinitialiser") {
                Button("Réinitialiser toutes les préférences", role: .destructive) {
                    isResetPreferencesConfirmationPresented = true
                }

                Button("Effacer les données de cet appareil", role: .destructive) {
                    isEraseDeviceConfirmationPresented = true
                }
            } footer: {
                Text("Les favoris, lieux et l’historique sont conservés lors de la réinitialisation des préférences.")
            }

            if let errorMessage = authSession.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
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
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Confirmer avec Apple")
                        .font(.title2.weight(.semibold))
                    Text("Apple doit confirmer ton identité avant la suppression définitive du compte.")
                        .foregroundStyle(.secondary)
                    AppleDeletionButton { outcome in
                        Task {
                            await authSession.completeAccountDeletion(outcome)
                            isAppleReauthorizationPresented = false
                        }
                    }
                    if authSession.isDeletingAccount {
                        ProgressView("Suppression en cours…")
                    }
                    Spacer()
                }
                .padding(24)
                .navigationTitle("Suppression")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") {
                            isAppleReauthorizationPresented = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func message(for error: ViaError) -> String {
        switch error {
        case .transport:
            "Connexion indisponible. Les modifications restent en attente."
        case .unavailable:
            "Le service est momentanément indisponible."
        case .unauthorized:
            "Reconnecte-toi pour synchroniser ce compte."
        default:
            "La synchronisation a échoué. Réessaie plus tard."
        }
    }
}
