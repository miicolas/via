import Observation

struct ChatItinerary: Identifiable, Sendable {
    let destination: JourneyDestination
    let response: JourneysResponse

    var id: String {
        response.journeys.first?.id ?? destination.id
    }
}

@MainActor
@Observable
final class ChatFeatureModel {
    private let client: any ChatClient
    private let locationProvider: any LocationProviding
    private var streamTask: Task<Void, Never>?

    private(set) var messages: [ChatMessage] = []
    private(set) var status: ChatStatus = .idle
    private(set) var errorMessage: String?
    private(set) var latestItinerary: ChatItinerary?

    init(client: any ChatClient, locationProvider: any LocationProviding) {
        self.client = client
        self.locationProvider = locationProvider
    }

    var isStreaming: Bool {
        status == .streaming
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        streamTask?.cancel()
        errorMessage = nil
        latestItinerary = nil
        messages.append(ChatMessage(role: .user, text: trimmed))
        status = .streaming

        let requestMessages = messages
        let location = locationProvider.coordinate
        let client = client
        streamTask = Task { [weak self] in
            do {
                try await client.stream(
                    messages: requestMessages,
                    location: location,
                    onEvent: { [weak self] event in
                        await self?.receive(event)
                    }
                )
                guard !Task.isCancelled else { return }
                self?.status = .ready
            } catch is CancellationError {
                guard !Task.isCancelled else { return }
                self?.status = .idle
            } catch let error as TransitAPIError where error == .cancelled {
                guard !Task.isCancelled else { return }
                self?.status = .idle
            } catch {
                guard !Task.isCancelled else { return }
                self?.errorMessage = "Via est momentanément indisponible. Réessayez dans un instant."
                self?.status = .failed
            }
        }
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        if isStreaming { status = .idle }
    }

    func reset() {
        cancel()
        messages = []
        latestItinerary = nil
        errorMessage = nil
        status = .idle
    }

    private func receive(_ event: ChatStreamEvent) {
        switch event {
        case .textDelta(let text):
            if let index = messages.lastIndex(where: { $0.role == .assistant }) {
                messages[index].text += text
            } else {
                messages.append(ChatMessage(role: .assistant, text: text))
            }
        case .itinerary(let destination, let response):
            latestItinerary = ChatItinerary(destination: destination, response: response)
        case .finished:
            status = .ready
        }
    }
}
