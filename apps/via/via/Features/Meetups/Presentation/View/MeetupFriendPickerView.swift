import SwiftUI

struct MeetupFriendPickerView: View {
    let model: FriendsModel
    let onSelect: (ViaFriend) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.friends.isEmpty {
                    EmptyStateView(.noFriends) {
                        EmptyStateHint(
                            Text("Ajoutez d’abord un ami depuis \(Image(systemName: "person.2")) Amis"),
                            label: "Ouvrir Amis depuis le menu du compte"
                        )
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(model.friends) { friend in
                        HStack(spacing: 12) {
                            InitialsAvatarView(
                                name: friend.displayName,
                                initials: friend.initials,
                                size: 48,
                                tint: .blue
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(friend.displayName)
                                    .font(.headline)
                                Text("Invitation directe")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Inviter \(friend.displayName)", systemImage: "paperplane.fill") {
                                onSelect(friend)
                                dismiss()
                            }
                            .iconAction(isProminent: true)
                        }
                        .padding(14)
                        .background(
                            Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .navigationTitle("Inviter un ami")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer", systemImage: "xmark", role: .close) { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .task { await model.load() }
    }
}
