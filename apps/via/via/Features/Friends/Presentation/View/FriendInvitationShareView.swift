import SwiftUI

struct FriendInvitationShareView: View {
    let link: FriendInvitationLink

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 82, height: 82)
                        .glassEffect(.regular.tint(.blue), in: .circle)
                        .accessibilityHidden(true)
                    Text("Ajouter un ami")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("Seule la personne qui possède ce lien opaque peut l’accepter.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Label {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Invitation temporaire")
                                .font(.headline)
                            Text("Expire le \(link.expiresAt.formatted(date: .abbreviated, time: .shortened)). Via n’utilise ni annuaire ni import de contacts.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.title2)
                            .foregroundStyle(.purple)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .detailCard()

                    ShareLink(item: link.url) {
                        Label("Partager le lien", systemImage: "square.and.arrow.up")
                    }
                    .primaryAction(tint: .blue)
                }
                .padding(24)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .navigationTitle("Invitation d’ami")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer", systemImage: "xmark", role: .close) { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
