import Foundation

protocol ChatClient: Sendable {
    func stream(
        messages: [ChatMessage],
        location: GeoCoordinate?,
        onEvent: @escaping @Sendable (ChatStreamEvent) async -> Void
    ) async throws
}

enum ChatClientError: Error, Equatable, Sendable {
    case invalidStream
}

struct ChatStreamParser: Sendable {
    private var buffer = Data()

    mutating func append(_ data: Data) throws -> [ChatStreamEvent] {
        buffer.append(data)
        var events: [ChatStreamEvent] = []

        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(buffer.startIndex...newline)
            if let event = try decode(line) {
                events.append(event)
            }
        }

        return events
    }

    mutating func finish() throws -> [ChatStreamEvent] {
        guard !buffer.isEmpty else { return [] }
        let line = buffer
        buffer.removeAll(keepingCapacity: false)
        return try decode(line).map { [$0] } ?? []
    }

    private func decode(_ line: Data) throws -> ChatStreamEvent? {
        let trimmed = line.drop { byte in
            byte == 0x20 || byte == 0x09 || byte == 0x0D
        }
        guard !trimmed.isEmpty else { return nil }

        do {
            return try JSONDecoder().decode(ChatStreamEvent.self, from: Data(trimmed))
        } catch {
            throw ChatClientError.invalidStream
        }
    }
}

final class URLSessionChatClient: ChatClient, @unchecked Sendable {
    private let baseURL: URL
    private let clientIdentifier: String
    private let session: URLSession

    init(baseURL: URL, clientIdentifier: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.clientIdentifier = clientIdentifier
        self.session = session
    }

    func stream(
        messages: [ChatMessage],
        location: GeoCoordinate?,
        onEvent: @escaping @Sendable (ChatStreamEvent) async -> Void
    ) async throws {
        let url = baseURL.appending(path: "ai/chat/v1")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
        request.setValue(clientIdentifier, forHTTPHeaderField: "x-via-client-id")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(messages: messages, location: location)
        )

        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TransitAPIError.server(statusCode: 0)
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw error(for: httpResponse.statusCode)
            }

            var parser = ChatStreamParser()
            for try await line in bytes.lines {
                for event in try parser.append(Data((line + "\n").utf8)) {
                    await onEvent(event)
                }
            }
            for event in try parser.finish() {
                await onEvent(event)
            }
        } catch let error as TransitAPIError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw TransitAPIError.cancelled
            case .timedOut: throw TransitAPIError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw TransitAPIError.offline
            default: throw TransitAPIError.server(statusCode: 0)
            }
        } catch is CancellationError {
            throw TransitAPIError.cancelled
        } catch {
            throw TransitAPIError.server(statusCode: 0)
        }
    }

    private func error(for statusCode: Int) -> TransitAPIError {
        switch statusCode {
        case 401, 403: .unauthorized
        case 429: .rateLimited
        default: .server(statusCode: statusCode)
        }
    }
}

private struct ChatRequest: Encodable, Sendable {
    struct Message: Encodable, Sendable {
        let role: ChatMessage.Role
        let content: String
    }

    let messages: [Message]
    let location: GeoCoordinate?

    init(messages: [ChatMessage], location: GeoCoordinate?) {
        self.messages = messages.map { Message(role: $0.role, content: $0.text) }
        self.location = location
    }
}

struct DemoChatClient: ChatClient {
    private let transitAPI: any TransitAPI

    init(transitAPI: any TransitAPI) {
        self.transitAPI = transitAPI
    }

    func stream(
        messages: [ChatMessage],
        location: GeoCoordinate?,
        onEvent: @escaping @Sendable (ChatStreamEvent) async -> Void
    ) async throws {
        let prompt = messages.last(where: { $0.role == .user })?.text ?? ""
        let normalized = prompt.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let isChatelet = normalized.contains("chatelet") || normalized.contains("châtelet")
        let answer = isChatelet
            ? "Je peux vous emmener à Châtelet. Voici le meilleur itinéraire depuis votre position."
            : "Je peux préparer un trajet en Île-de-France. Essayez par exemple : « Comment aller à Châtelet ? »"

        for word in answer.split(separator: " ", omittingEmptySubsequences: false) {
            try await Task.sleep(for: .milliseconds(24))
            await onEvent(.textDelta(String(word) + " "))
        }

        if isChatelet, let location {
            let destination = JourneyDestination(
                kind: .station,
                id: "demo:chatelet",
                name: "Châtelet",
                context: nil,
                coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3470)
            )
            let response = try await transitAPI.planJourneys(
                JourneyRequest(origin: location, destination: destination)
            )
            await onEvent(.itinerary(destination: destination, response: response))
        }

        await onEvent(.finished)
    }
}
