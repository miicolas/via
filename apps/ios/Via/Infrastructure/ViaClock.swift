import Foundation

protocol ViaClock: Sendable {
    func sleep(for duration: Duration) async throws
}

struct SystemViaClock: ViaClock {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

struct ImmediateViaClock: ViaClock {
    func sleep(for duration: Duration) async throws {}
}
