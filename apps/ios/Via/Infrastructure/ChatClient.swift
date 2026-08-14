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
    private let clientMetadata: NativeClientMetadata
    private let session: URLSession
    private let logger: ViaLogger

    init(
        baseURL: URL,
        clientIdentifier: String,
        clientMetadata: NativeClientMetadata = .current,
        session: URLSession = .shared,
        logger: ViaLogger = ViaLogger(category: "chat")
    ) {
        self.baseURL = baseURL
        self.clientIdentifier = clientIdentifier
        self.clientMetadata = clientMetadata
        self.session = session
        self.logger = logger
    }

    func stream(
        messages: [ChatMessage],
        location: GeoCoordinate?,
        onEvent: @escaping @Sendable (ChatStreamEvent) async -> Void
    ) async throws {
        let url = baseURL.appending(path: "ai/chat/v1")
        let operation = "chat.stream"
        let path = "/ai/chat/v1"
        let startedAt = Date()
        logger.requestStarted(operation: operation, path: path)

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
            request.setValue(clientIdentifier, forHTTPHeaderField: "x-via-client-id")
            request.setValue(clientMetadata.platform, forHTTPHeaderField: "x-via-client-platform")
            request.setValue(clientMetadata.version, forHTTPHeaderField: "x-via-client-version")
            request.setValue(clientMetadata.build, forHTTPHeaderField: "x-via-client-build")
            request.httpBody = try JSONEncoder().encode(
                ChatRequest(messages: messages, location: location)
            )

            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TransitAPIError.server(statusCode: 0)
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw TransitAPIError.from(statusCode: httpResponse.statusCode)
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
            logger.requestSucceeded(
                operation: operation,
                path: path,
                durationMilliseconds: max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
            )
        } catch let error as TransitAPIError {
            logger.requestFailed(operation: operation, path: path, error: error)
            throw error
        } catch let error as URLError {
            let mappedError = TransitAPIError.from(error)
            logger.requestFailed(operation: operation, path: path, error: mappedError)
            throw mappedError
        } catch is CancellationError {
            let mappedError = TransitAPIError.cancelled
            logger.requestFailed(operation: operation, path: path, error: mappedError)
            throw mappedError
        } catch {
            let mappedError = TransitAPIError.from(error)
            logger.requestFailed(operation: operation, path: path, error: mappedError)
            throw mappedError
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
