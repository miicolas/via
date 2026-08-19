import SwiftUI

struct AccountSynchronizationSection: View {
    let state: AccountSyncState
    let isSignedIn: Bool
    let onSynchronize: () -> Void

    var body: some View {
        Section("Synchronisation") {
            HStack {
                SyncStatusLabel(state: state)
                Spacer()
                if state == .syncing {
                    ProgressView()
                }
            }
            .frame(minHeight: 44)

            Button(action: onSynchronize) {
                Label("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!isSignedIn)

            if case .failed(let error) = state {
                Text(message(for: error))
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func message(for error: ViaError) -> String {
        switch error {
        case .transport:
            "Connexion indisponible. Les modifications restent en attente."
        case .unavailable:
            "Le service est momentanément indisponible."
        case .unauthorized:
            "Reconnecte-toi pour synchroniser ce compte."
        default:
            "La synchronisation a échoué. Réessaie plus tard."
        }
    }
}
