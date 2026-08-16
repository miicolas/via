import Foundation

struct ChatMessage: Sendable, Hashable, Identifiable {
    enum Role: String, Codable, Sendable, Hashable { case user, assistant }
    enum Delivery: Sendable, Hashable { case sending, streaming, sent, failed }

    let id: String
    let role: Role
    var text: String
    var delivery: Delivery
}

struct ChatItinerary: Sendable, Hashable {
    let destination: JourneyDestination
    let requestedAt: Date?
    let datetimeRepresents: JourneyDatetimeRepresents?
    let result: JourneyResult
}

enum ChatUnavailableReason: Sendable, Hashable {
    case deviceNotEligible
    case appleIntelligenceDisabled
    case modelNotReady
    case unsupportedLanguage

    var message: String {
        switch self {
        case .deviceNotEligible:
            "Le chat nécessite un iPhone compatible avec Apple Intelligence."
        case .appleIntelligenceDisabled:
            "Activez Apple Intelligence dans Réglages pour utiliser le chat."
        case .modelNotReady:
            "Le modèle Apple Intelligence n’est pas encore prêt."
        case .unsupportedLanguage:
            "Le modèle Apple Intelligence ne prend pas en charge le français sur cet appareil."
        }
    }
}

enum ChatAvailability: Sendable, Hashable {
    case available
    case unavailable(ChatUnavailableReason)
}

enum ChatResponseSnapshot: Sendable, Hashable {
    case streaming(text: String)
    case completed(text: String, itinerary: ChatItinerary?)
    case unavailable(ChatUnavailableReason)
    case failure(code: String, retryable: Bool, message: String)
}

struct ChatRequest: Sendable, Hashable {
    let messages: [ChatMessage]
    let location: GeoCoordinate?
}
