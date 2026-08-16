import Foundation

protocol ChatRepository: Sendable {
    var availability: ChatAvailability { get }
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<ChatResponseSnapshot, Error>
}

struct InMemoryChatRepository: ChatRepository {
    var availability: ChatAvailability = .available
    var snapshots: [ChatResponseSnapshot] = []

    func stream(_ request: ChatRequest) -> AsyncThrowingStream<ChatResponseSnapshot, Error> {
        AsyncThrowingStream { continuation in
            for snapshot in snapshots { continuation.yield(snapshot) }
            continuation.finish()
        }
    }
}
