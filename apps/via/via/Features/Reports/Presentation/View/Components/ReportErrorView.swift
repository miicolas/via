import SwiftUI

struct ReportErrorView: View {
    let error: ViaError
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Signalement non envoyé", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Réessayer", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(20)
    }

    private var message: String {
        switch error {
        case .invalidConfiguration:
            "La configuration de Via est invalide."
        case .invalidRequest:
            "Le signalement n’est pas valide."
        case .transport, .decoding, .unavailable, .server:
            "Réessayez dans un instant."
        case .unauthorized:
            "Aucune connexion n’est nécessaire pour signaler."
        case .rateLimited:
            "Trop de signalements ont été envoyés récemment."
        }
    }
}
