import SwiftUI

struct MeetupInvitationRow: View {
    let invitation: MeetupInvitation
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: invitation.invitedUserId == nil ? "link" : "person.fill")
                .foregroundStyle(.secondary)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(invitation.invitedUserId == nil ? "Invitation par lien" : "Invitation directe")
                Text("Expire le \(invitation.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .layoutPriority(1)
            Spacer()
            Button("Révoquer l’invitation", systemImage: "xmark", role: .destructive) {
                onRevoke()
            }
                .iconAction(size: .regular)
                .tint(.red)
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}
