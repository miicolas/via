import AuthenticationServices
import SwiftUI

struct AccountView: View {
    @Bindable var authViewModel: AuthSessionViewModel
    let account: AccountModel

    @Environment(\.dismiss) private var dismiss
    @State private var authorizationAdapter = AppleAuthorizationAdapter()
    @State private var deletionConfirmationPresented = false
    @State private var deletionAuthorizationRequested = false

    var body: some View {
        NavigationStack {
            List {
                if let session = authViewModel.session {
                    Section {
                        HStack(spacing: 16) {
                            AccountAvatarView(user: session.user)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.user.displayName)
                                    .font(.headline)
                                Text(session.user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section("Synchronisation") {
                    synchronizationContent
                }

                Section("Stations favorites") {
                    if account.favorites.isEmpty {
                        Text("Ajoute une station depuis sa fiche pour la retrouver ici.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(account.favorites) { favorite in
                            Label(favorite.name, systemImage: "star.fill")
                        }
                        .onDelete(perform: removeFavorites)
                    }
                }

                Section("Transports préférés") {
                    ForEach(TransitMode.allCases, id: \.self) { mode in
                        Toggle(mode.displayName, isOn: preferredBinding(for: mode))
                    }
                }

                Section {
                    Button("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right") {
                        Task {
                            await authViewModel.signOut()
                            dismiss()
                        }
                    }

                    Button(
                        "Supprimer le compte",
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        deletionConfirmationPresented = true
                    }
                }

                if deletionAuthorizationRequested {
                    Section("Confirmation Apple") {
                        Text("Apple doit confirmer ton identité avant la révocation et la suppression définitive.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        SignInWithAppleButton(
                            .continue,
                            onRequest: authorizationAdapter.configureDeletionRequest,
                            onCompletion: { result in
                                let outcome = authorizationAdapter.deletionOutcome(from: result)
                                Task { await authViewModel.completeAccountDeletion(outcome) }
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 48)
                        .disabled(authViewModel.isDeletingAccount)

                        if authViewModel.isDeletingAccount {
                            ProgressView("Révocation et suppression…")
                        }
                    }
                }

                if let errorMessage = authViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Compte")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
            .alert(
                "Supprimer définitivement le compte ?",
                isPresented: $deletionConfirmationPresented
            ) {
                Button("Annuler", role: .cancel) {}
                Button("Continuer avec Apple", role: .destructive) {
                    deletionAuthorizationRequested = true
                }
            } message: {
                Text("Les favoris, recherches, préférences et sessions seront supprimés après révocation Apple.")
            }
            .sensoryFeedback(.warning, trigger: deletionAuthorizationRequested) { _, isRequested in
                isRequested
            }
            .sensoryFeedback(.error, trigger: authViewModel.errorMessage) { _, newMessage in
                newMessage != nil
            }
        }
    }

    @ViewBuilder
    private var synchronizationContent: some View {
        switch account.syncState {
        case .local:
            Label("Données locales", systemImage: "internaldrive")
                .foregroundStyle(.secondary)
        case .syncing:
            HStack {
                ProgressView()
                Text("Synchronisation…")
            }
        case .synced:
            Label("Synchronisé", systemImage: "checkmark.icloud.fill")
                .foregroundStyle(.green)
        case .pendingOffline:
            Label("En attente de connexion", systemImage: "wifi.slash")
                .foregroundStyle(.orange)
            Button("Réessayer", systemImage: "arrow.clockwise") {
                account.retrySynchronization()
            }
        case .failed:
            Label("Échec de synchronisation", systemImage: "exclamationmark.icloud")
                .foregroundStyle(.red)
            Button("Réessayer", systemImage: "arrow.clockwise") {
                account.retrySynchronization()
            }
        }
    }

    private func preferredBinding(for mode: TransitMode) -> Binding<Bool> {
        Binding(
            get: { account.transportPreferences.preferredModes.contains(mode) },
            set: { isPreferred in
                account.setPreferred(mode, enabled: isPreferred)
            }
        )
    }

    private func removeFavorites(at offsets: IndexSet) {
        let removed = offsets.map { account.favorites[$0] }
        for favorite in removed {
            account.removeFavorite(stationID: favorite.stationID)
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview
    AccountView(
        authViewModel: dependencies.authSession,
        account: dependencies.root.account
    )
}
