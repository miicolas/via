import SwiftUI

struct FriendsView: View {
    let model: FriendsModel
    let authSessionViewModel: AuthSessionViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var inviteTick = 0
    @State private var removeTick = 0
    @State private var friendToRemove: ViaFriend?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Amis")
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Fermer", systemImage: "xmark", role: .close) {
                            dismiss()
                        }
                        .labelStyle(.iconOnly)
                    }
                    if authSessionViewModel.isSignedIn {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                inviteTick += 1
                                Task { await model.createInvitation() }
                            } label: {
                                Image(systemName: "person.badge.plus")
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Inviter un ami")
                        }
                    }
                }
                .navigationDestination(for: ViaFriend.self) { friend in
                    FriendDetailView(friend: friend) {
                        await model.remove(friend)
                    }
                }
        }
        .task(id: authSessionViewModel.session?.user.id) {
            guard authSessionViewModel.isSignedIn else { return }
            await model.load()
        }
        .sheet(item: Binding(
            get: { model.invitationLink },
            set: { if $0 == nil { model.clearInvitationLink() } }
        )) { link in
            FriendInvitationShareView(link: link)
        }
        .confirmationDialog(
            friendToRemove.map { "Retirer \($0.displayName) de vos amis ?" }
                ?? "Retirer cet ami ?",
            isPresented: Binding(
                get: { friendToRemove != nil },
                set: { if !$0 { friendToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Retirer", role: .destructive) {
                guard let friend = friendToRemove else { return }
                friendToRemove = nil
                Task { await model.remove(friend) }
            }
        } message: {
            Text("Cette personne ne pourra plus être invitée directement à un rendez-vous.")
        }
        .alert(
            "Action impossible",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) { model.clearError() }
        } message: {
            Text(model.errorMessage ?? "Réessayez dans un instant.")
        }
        .haptic(Haptic.commit, on: inviteTick)
        .haptic(Haptic.warned, on: removeTick)
    }

    @ViewBuilder
    private var content: some View {
        if !authSessionViewModel.isSignedIn {
            EmptyStateView(
                .unavailable(
                    title: "Compte requis",
                    message: "Les relations d’amitié sont réservées aux comptes Sign in with Apple."
                )
            ) {
                AppleSignInButton(authSessionViewModel: authSessionViewModel)
            }
            .padding(20)
            .frame(maxHeight: .infinity)
        } else {
            switch model.state {
            case .idle where model.friends.isEmpty,
                 .loading where model.friends.isEmpty:
                SkeletonList(count: 4, label: "Chargement des amis…", row: .searchResult)
                    .padding(.horizontal, 20)
            case .failed where model.friends.isEmpty:
                EmptyStateView(.offline(title: "Amis indisponibles")) {
                    RetryButton { Task { await model.load() } }
                        .primaryAction()
                }
                .frame(maxHeight: .infinity)
            default:
                if model.friends.isEmpty {
                    EmptyStateView(.noFriends) {
                        EmptyStateHint(
                            Text("Touchez \(Image(systemName: "person.badge.plus")) pour créer un lien d’ami"),
                            label: "Créer un lien d’ami"
                        ) {
                            inviteTick += 1
                            Task { await model.createInvitation() }
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        FriendsSummaryView(friends: model.friends)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 14, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        Section {
                            ForEach(model.friends) { friend in
                                NavigationLink(value: friend) {
                                    FriendRowView(friend: friend)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        removeTick += 1
                                        friendToRemove = friend
                                    } label: {
                                        Label("Supprimer", systemImage: "person.fill.xmark")
                                            .labelStyle(.iconOnly)
                                    }
                                    .accessibilityLabel("Supprimer \(friend.displayName)")
                                }
                            }
                        } header: {
                            Text("Vos amis")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.horizontal, 20, for: .scrollContent)
                    .background(Color(uiColor: .systemGroupedBackground))
                    .hapticRefreshable { await model.load() }
                }
            }
        }
    }
}
