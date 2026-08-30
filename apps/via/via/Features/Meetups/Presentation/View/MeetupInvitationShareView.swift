import SwiftUI

struct MeetupInvitationShareView: View {
    let link: MeetupInvitationLink

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 82, height: 82)
                        .glassEffect(.regular.tint(.blue), in: .circle)
                        .accessibilityHidden(true)
                    Text("Inviter au rendez-vous")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("Une place, un lien temporaire, aucun accès au reste de votre compte.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 0) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Capacité limitée")
                                    .font(.headline)
                                Text("Le lien ne permet de rejoindre que ce rendez-vous.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "link.badge.plus")
                                .foregroundStyle(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 16)

                        Divider()

                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Position chiffrée")
                                    .font(.headline)
                                Text("La clé reste après # et n’est jamais envoyée au serveur.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.purple)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)
                    }
                    .detailCard()

                    Text("Expire le \(link.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)

                    ShareLink(item: link.url) {
                        Label("Partager l’invitation", systemImage: "square.and.arrow.up")
                    }
                    .primaryAction(tint: .blue)
                }
                .padding(24)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .navigationTitle("Invitation")
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
