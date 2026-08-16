import SwiftUI

struct ConfigurationErrorView: View {
    let error: ViaError

    var body: some View {
        ContentUnavailableView {
            Label("Via ne peut pas démarrer", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(message)
        }
        .accessibilityIdentifier("configuration-error")
    }

    private var message: String {
        if case .invalidConfiguration(let message) = error {
            return message
        }
        return "La configuration de l’application est invalide."
    }
}

#Preview {
    ConfigurationErrorView(
        error: .invalidConfiguration("VIA_API_BASE_URL est absente ou invalide")
    )
}
