import Foundation

struct ChatMessage: Codable, Hashable, Identifiable, Sendable {
    enum Role: String, Codable, Hashable, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

enum ChatStatus: Equatable, Sendable {
    case idle
    case streaming
    case ready
    case failed
}

enum ChatStreamEvent: Codable, Sendable {
    case textDelta(String)
    case itinerary(destination: JourneyDestination, response: JourneysResponse)
    case finished

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case destination
        case journeys
    }

    private enum EventType: String, Codable {
        case textDelta = "text_delta"
        case itinerary
        case finished
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(EventType.self, forKey: .type) {
        case .textDelta:
            self = .textDelta(try container.decode(String.self, forKey: .text))
        case .itinerary:
            self = .itinerary(
                destination: try container.decode(JourneyDestination.self, forKey: .destination),
                response: try container.decode(JourneysResponse.self, forKey: .journeys)
            )
        case .finished:
            self = .finished
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .textDelta(let text):
            try container.encode(EventType.textDelta, forKey: .type)
            try container.encode(text, forKey: .text)
        case .itinerary(let destination, let response):
            try container.encode(EventType.itinerary, forKey: .type)
            try container.encode(destination, forKey: .destination)
            try container.encode(response, forKey: .journeys)
        case .finished:
            try container.encode(EventType.finished, forKey: .type)
        }
    }
}
