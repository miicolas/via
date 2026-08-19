import SwiftUI

struct AccountCardView: View {
    let account: AccountModel
    let authSession: AuthSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let session = authSession.session {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.user.displayName)
                            .font(.headline)
                        Text(session.user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                }

                SyncStatusLabel(state: account.syncState)
            } else {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Utiliser Via sans compte")
                            .font(.headline)
                        Text("Tes favoris et lieux restent sur cet appareil.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "iphone")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                }

                Text("Connecte-toi avec Apple pour synchroniser tes données entre tes appareils.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                switch authSession.state {
                case .loading:
                    ProgressView("Préparation de la session…")
                        .frame(maxWidth: .infinity, minHeight: 44)
                case .authenticating:
                    ProgressView("Connexion à Apple…")
                        .frame(maxWidth: .infinity, minHeight: 44)
                default:
                    AppleSignInButton { outcome in
                        Task { await authSession.completeSignIn(outcome) }
                    }
                }
            }

            if let errorMessage = authSession.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }
}

struct SyncStatusLabel: View {
    let state: AccountSyncState

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.footnote)
            .foregroundStyle(color)
            .symbolEffect(.pulse, isActive: state == .syncing)
    }

    private var title: String {
        switch state {
        case .local:
            "Données locales"
        case .syncing:
            "Synchronisation…"
        case .synced:
            "Synchronisé"
        case .pendingOffline:
            "En attente — hors ligne"
        case .failed:
            "Synchronisation impossible"
        }
    }

    private var symbol: String {
        switch state {
        case .local: "iphone"
        case .syncing: "arrow.triangle.2.circlepath"
        case .synced: "checkmark.icloud"
        case .pendingOffline: "wifi.slash"
        case .failed: "exclamationmark.icloud"
        }
    }

    private var color: Color {
        switch state {
        case .failed: .red
        case .pendingOffline: .orange
        default: .secondary
        }
    }
}
