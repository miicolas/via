import Foundation

struct JourneyErrorPresentation: Equatable, Sendable {
    let title: String
    let message: String
    let systemImage: String

    init(error: ViaError) {
        switch error {
        case .unauthorized:
            title = "Session expirée"
            message = "Reconnecte-toi avec Apple, puis réessaie."
            systemImage = "person.crop.circle.badge.exclamationmark"
        case .rateLimited, .unavailable, .server:
            title = "Service momentanément indisponible"
            message = "Le calcul d’itinéraire est momentanément indisponible. Réessaie dans un instant."
            systemImage = "hourglass"
        case .decoding:
            title = "Réponse invalide"
            message = "Le service a renvoyé une réponse inattendue. Réessaie dans un instant."
            systemImage = "exclamationmark.triangle"
        case .invalidRequest:
            title = "Itinéraire impossible"
            message = "Modifie le départ ou l’arrivée, puis réessaie."
            systemImage = "exclamationmark.triangle"
        case .invalidConfiguration, .transport:
            title = "Itinéraires indisponibles"
            message = "Vérifie ta connexion, puis réessaie."
            systemImage = "wifi.exclamationmark"
        }
    }
}
