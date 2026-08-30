import SwiftUI

struct MeetupPendingInvitationCard: View {
    let invitation: MeetupPendingInvitation

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .background(.blue.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Invitation de \(invitation.organizerDisplayName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(invitation.destination.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(
                    invitation.targetArrivalAt.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "clock.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.blue)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.13), .purple.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Ouvre l’invitation")
    }
}
