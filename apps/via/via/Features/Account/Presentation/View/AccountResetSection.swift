import SwiftUI

struct AccountResetSection: View {
    @Binding var isResetPreferencesConfirmationPresented: Bool
    @Binding var isEraseDeviceConfirmationPresented: Bool

    var body: some View {
        Section("Réinitialiser") {
            Button("Réinitialiser toutes les préférences", role: .destructive) {
                isResetPreferencesConfirmationPresented = true
            }

            Button("Effacer les données de cet appareil", role: .destructive) {
                isEraseDeviceConfirmationPresented = true
            }
        } footer: {
            Text("Les favoris, lieux et l’historique sont conservés lors de la réinitialisation des préférences.")
        }
    }
}
