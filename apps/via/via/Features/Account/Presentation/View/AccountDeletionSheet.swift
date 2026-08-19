import SwiftUI

struct AccountDeletionSheet: View {
    let isDeletingAccount: Bool
    let onOutcome: (AppleDeletionOutcome) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Confirmer avec Apple")
                    .font(.title2.weight(.semibold))
                Text("Apple doit confirmer ton identité avant la suppression définitive du compte.")
                    .foregroundStyle(.secondary)
                AppleDeletionButton(onCompletion: onOutcome)
                if isDeletingAccount {
                    ProgressView("Suppression en cours…")
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("Suppression")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
