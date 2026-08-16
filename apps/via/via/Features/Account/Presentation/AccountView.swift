import AuthenticationServices
import SwiftUI

struct AccountView: View {
    @Bindable var authViewModel: AuthSessionViewModel
    let favoriteStations: any FavoriteStationRepository
    let transportPreferences: any TransportPreferencesRepository

    @Environment(\.dismiss) private var dismiss
    @State private var favorites: [FavoriteStation] = []
    @State private var preferences: TransportPreferences = .empty
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
                    LabeledContent("État") {
                        Label(
                            authViewModel.connectivity == .offline ? "Hors connexion" : "Synchronisé",
                            systemImage: authViewModel.connectivity == .offline
                                ? "wifi.slash"
                                : "checkmark.icloud.fill"
                        )
                        .foregroundStyle(
                            authViewModel.connectivity == .offline ? Color.orange : Color.green
                        )
                    }
                }

                Section("Stations favorites") {
                    if favorites.isEmpty {
                        Text("Ajoute une station depuis sa fiche pour la retrouver ici.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(favorites) { favorite in
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
                            onRequest: authViewModel.configureDeletionRequest,
                            onCompletion: { result in
                                Task { await authViewModel.completeAccountDeletion(result) }
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
            .onAppear {
                favorites = favoriteStations.favorites()
                preferences = transportPreferences.load()
            }
        }
    }

    private func preferredBinding(for mode: TransitMode) -> Binding<Bool> {
        Binding(
            get: { preferences.preferredModes.contains(mode) },
            set: { isPreferred in
                if isPreferred {
                    preferences.preferredModes.insert(mode)
                    preferences.excludedModes.remove(mode)
                } else {
                    preferences.preferredModes.remove(mode)
                }
                preferences.updatedAt = .now
                transportPreferences.store(preferences)
            }
        )
    }

    private func removeFavorites(at offsets: IndexSet) {
        let removed = offsets.map { favorites[$0] }
        favorites.remove(atOffsets: offsets)
        for favorite in removed {
            favoriteStations.remove(stationID: favorite.stationID)
        }
    }
}

#Preview {
    AccountView(
        authViewModel: .preview,
        favoriteStations: AppDependencies.preview.favoriteStations,
        transportPreferences: AppDependencies.preview.transportPreferences
    )
}
