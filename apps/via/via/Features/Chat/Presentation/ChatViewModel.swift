import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    enum State: Sendable, Equatable {
        case idle
        case streaming
        case completed
        case unavailable(ChatUnavailableReason)
        case failed(message: String, retryable: Bool)
    }

    private(set) var messages: [ChatMessage] = []
    private(set) var itinerary: ChatItinerary?
    private(set) var state: State

    @ObservationIgnored private let repository: any ChatRepository
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var lastLocation: GeoCoordinate?
    @ObservationIgnored private var streamingIndex: Int?

    init(repository: any ChatRepository) {
        self.repository = repository
        state = Self.state(for: repository.availability)
    }

    func send(_ text: String, location: GeoCoordinate?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, state != .streaming, ensureAvailability() else { return }
        lastLocation = location
        messages.append(ChatMessage(id: UUID().uuidString, role: .user, text: value, delivery: .sent))
        startStream()
    }

    func retry() {
        guard state != .streaming, ensureAvailability() else { return }
        startStream()
    }

    func refreshAvailability() {
        guard state != .streaming else { return }
        switch repository.availability {
        case .available:
            if case .unavailable = state { state = .idle }
        case .unavailable(let reason):
            state = .unavailable(reason)
        }
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        discardAssistant(finalDelivery: .sent)
        state = Self.state(for: repository.availability)
    }

    func resetSession() {
        cancel()
        messages = []
        itinerary = nil
    }

    private func startStream() {
        streamTask?.cancel()
        itinerary = nil
        messages.append(ChatMessage(id: UUID().uuidString, role: .assistant, text: "", delivery: .streaming))
        streamingIndex = messages.count - 1
        state = .streaming
        let request = ChatRequest(
            messages: messages.filter { !$0.text.isEmpty && $0.delivery != .failed },
            location: lastLocation
        )

        streamTask = Task {
            do {
                for try await snapshot in repository.stream(request) {
                    try Task.checkCancellation()
                    switch snapshot {
                    case .streaming(let text):
                        updateAssistant(text: text, delivery: .streaming)
                    case .completed(let text, let value):
                        updateAssistant(text: text, delivery: .sent)
                        itinerary = value
                        state = .completed
                    case .unavailable(let reason):
                        discardAssistant()
                        state = .unavailable(reason)
                    case .failure(_, let retryable, let message):
                        discardAssistant()
                        state = .failed(message: message, retryable: retryable)
                    }
                }
                if state == .streaming {
                    discardAssistant()
                    state = .failed(message: "La conversation a été interrompue.", retryable: true)
                }
            } catch is CancellationError { }
            catch {
                discardAssistant()
                state = .failed(message: "La conversation a été interrompue.", retryable: true)
            }
        }
    }

    private func updateAssistant(text: String, delivery: ChatMessage.Delivery) {
        guard let index = streamingIndex else { return }
        messages[index].text = text
        messages[index].delivery = delivery
        if delivery != .streaming { streamingIndex = nil }
    }

    private func discardAssistant(finalDelivery: ChatMessage.Delivery = .failed) {
        guard let index = streamingIndex else { return }
        streamingIndex = nil
        if messages[index].text.isEmpty {
            messages.remove(at: index)
        } else {
            messages[index].delivery = finalDelivery
        }
    }

    private func ensureAvailability() -> Bool {
        switch repository.availability {
        case .available:
            return true
        case .unavailable(let reason):
            state = .unavailable(reason)
            return false
        }
    }

    private static func state(for availability: ChatAvailability) -> State {
        switch availability {
        case .available: .idle
        case .unavailable(let reason): .unavailable(reason)
        }
    }
}
