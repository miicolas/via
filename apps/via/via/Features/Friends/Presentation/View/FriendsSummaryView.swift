import SwiftUI

struct FriendsSummaryView: View {
    let friends: [ViaFriend]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 18))

        layout {
            avatarStack

            VStack(alignment: .leading, spacing: 6) {
                Text(countLabel)
                    .font(.title2.weight(.bold))
                Text("Des liens privés, prêts à rejoindre vos prochains rendez-vous.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .detailCard()
        .accessibilityElement(children: .combine)
    }

    private var avatarStack: some View {
        HStack(spacing: -14) {
            ForEach(Array(friends.prefix(3).enumerated()), id: \.element.id) { index, friend in
                InitialsAvatarView(
                    name: friend.displayName,
                    initials: friend.initials,
                    size: 52,
                    tint: tints[index % tints.count]
                )
                .overlay { Circle().stroke(.background, lineWidth: 3) }
                .zIndex(Double(friends.count - index))
            }
        }
        .frame(minWidth: 76, alignment: .leading)
        .accessibilityHidden(true)
    }

    private var countLabel: String {
        friends.count == 1 ? "1 ami" : "\(friends.count) amis"
    }

    private var tints: [Color] { [.blue, .purple, .orange] }
}
