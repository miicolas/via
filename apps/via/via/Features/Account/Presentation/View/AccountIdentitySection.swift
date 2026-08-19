import SwiftUI

struct AccountIdentitySection: View {
    let session: StoredAuthSession?
    @Binding var isDeleteAccountConfirmationPresented: Bool
    let onSignOut: () -> Void

    var body: some View {
        if let session {
            Section("Compte Apple") {
                LabeledContent("Nom", value: session.user.displayName)
                LabeledContent("E-mail", value: session.user.email)

                Button("Se déconnecter", role: .destructive, action: onSignOut)

                Button("Supprimer le compte", role: .destructive) {
                    isDeleteAccountConfirmationPresented = true
                }
            }
        } else {
            Section {
                Text("Les données de cet appareil restent disponibles sans compte.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Espace local")
            }
        }
    }
}
