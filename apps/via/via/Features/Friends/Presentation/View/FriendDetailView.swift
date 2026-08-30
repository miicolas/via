import SwiftUI

struct FriendDetailView: View {
    let friend: ViaFriend
    let onRemove: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var asksToRemove = false
    @State private var removeTick = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    InitialsAvatarView(
                        name: friend.displayName,
                        initials: friend.initials,
                        size: 94,
                        tint: .blue
                    )
                    Text(friend.displayName)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("Ami depuis \(friend.createdAt.formatted(date: .long, time: .omitted))")
                        .foregroundStyle(.secondary)
                }

                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Prêt pour un rendez-vous")
                            .font(.headline)
                        Text("Vous pouvez inviter directement \(friend.displayName) au moment de choisir les participants.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "person.2.wave.2.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .detailCard()

                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Relation privée")
                            .font(.headline)
                        Text("Via ne crée aucun annuaire et n’importe jamais vos contacts.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "hand.raised.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .detailCard()

                Button("Retirer cet ami", systemImage: "person.fill.xmark", role: .destructive) {
                    removeTick += 1
                    asksToRemove = true
                }
                .secondaryAction()
                .tint(.red)
            }
            .padding(20)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .navigationTitle(friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Retirer \(friend.displayName) de vos amis ?",
            isPresented: $asksToRemove,
            titleVisibility: .visible
        ) {
            Button("Retirer", role: .destructive) {
                Task {
                    if await onRemove() { dismiss() }
                }
            }
        } message: {
            Text("Cette personne ne pourra plus être invitée directement à un rendez-vous.")
        }
        .haptic(Haptic.warned, on: removeTick)
    }
}
