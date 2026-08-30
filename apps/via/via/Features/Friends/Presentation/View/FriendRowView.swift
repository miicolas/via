import SwiftUI

struct FriendRowView: View {
    let friend: ViaFriend

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                regularLayout
            }
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Ouvre les détails de cette relation")
    }

    private var regularLayout: some View {
        HStack(spacing: 14) {
            avatar
            copy

            Spacer(minLength: 8)

            chevron
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                avatar
                Spacer(minLength: 8)
                chevron
            }

            copy
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var avatar: some View {
        InitialsAvatarView(
            name: friend.displayName,
            initials: friend.initials,
            size: 50,
            tint: .blue
        )
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(friend.displayName)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Ami depuis \(friend.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.forward")
            .font(.caption.weight(.bold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}
