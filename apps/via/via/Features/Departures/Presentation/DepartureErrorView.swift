import SwiftUI

struct DepartureErrorView: View {
    let error: ViaError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Impossible de charger les passages")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Réessayer", systemImage: "arrow.clockwise", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var message: String {
        switch error {
        case .transport:
            "Vérifie ta connexion, puis réessaie."
        case .rateLimited, .unavailable:
            "Le service d’horaires est momentanément indisponible."
        default:
            "Une erreur est survenue pendant le chargement des horaires."
        }
    }
}
