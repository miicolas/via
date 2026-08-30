import SwiftUI

struct FriendInvitationView: View {
    let model: FriendsModel
    let authSessionViewModel: AuthSessionViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var acceptedTick = 0
    @State private var acceptedFriendName: String?

    var body: some View {
        NavigationStack {
            Group {
                if let acceptedFriendName {
                    success(acceptedFriendName)
                } else {
                    content
                }
            }
                .navigationTitle("Invitation d’ami")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fermer", systemImage: "xmark", role: .close) { dismiss() }
                            .labelStyle(.iconOnly)
                    }
                }
        }
        .alert(
            "Invitation impossible",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) { model.clearError() }
        } message: {
            Text(model.errorMessage ?? "Réessayez dans un instant.")
        }
        .haptic(Haptic.saved, on: acceptedTick)
    }

    @ViewBuilder
    private var content: some View {
        switch model.invitationPreview {
        case .idle, .loading:
            EmptyStateView(.searching("Lecture de l’invitation…"))
                .frame(maxHeight: .infinity)
        case .failed:
            EmptyStateView(.unavailable(
                title: "Invitation indisponible",
                message: "Ce lien est invalide ou le service ne répond pas."
            )).frame(maxHeight: .infinity)
        case .loaded(let preview):
            if preview.status != .available {
                EmptyStateView(preview.status == .expired ? .meetupExpired : .meetupRevoked)
                    .frame(maxHeight: .infinity)
            } else if !authSessionViewModel.isSignedIn {
                EmptyStateView(
                    .unavailable(
                        title: "Connectez-vous pour ajouter \(preview.inviterDisplayName)",
                        message: "Les amis restent liés à votre compte Apple."
                    )
                ) {
                    AppleSignInButton(authSessionViewModel: authSessionViewModel)
                }
                .padding(20)
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 26) {
                        VStack(spacing: 14) {
                            InitialsAvatarView(
                                name: preview.inviterDisplayName,
                                initials: preview.inviterInitials,
                                size: 92,
                                tint: .blue
                            )
                            Text("\(preview.inviterDisplayName) vous invite")
                                .font(.largeTitle.weight(.bold))
                                .multilineTextAlignment(.center)
                            Text("Ajoutez cette personne à vos amis pour l’inviter directement à vos prochains rendez-vous.")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Label {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Un lien, une personne")
                                    .font(.headline)
                                Text("Le lien est opaque, temporaire et ne crée aucun annuaire public.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "lock.shield.fill")
                                .font(.title2)
                                .foregroundStyle(.purple)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .detailCard()

                        Button("Ajouter aux amis", systemImage: "person.badge.plus") {
                            Task {
                                if await model.acceptInvitation() {
                                    acceptedFriendName = preview.inviterDisplayName
                                    acceptedTick += 1
                                }
                            }
                        }
                        .primaryAction(tint: .blue)
                    }
                    .padding(24)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .scrollEdgeEffectStyle(.soft, for: .vertical)
            }
        }
    }

    private func success(_ name: String) -> some View {
        VStack(spacing: 22) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 84, height: 84)
                .glassEffect(.regular.tint(.blue), in: .circle)
                .accessibilityHidden(true)
            Text("Vous êtes maintenant amis")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("\(name) apparaîtra dans le choix des participants de vos rendez-vous.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Terminer", systemImage: "checkmark") { dismiss() }
                .primaryAction(tint: .blue)
        }
        .padding(24)
        .frame(maxHeight: .infinity)
    }
}
