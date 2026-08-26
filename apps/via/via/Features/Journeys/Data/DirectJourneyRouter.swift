import Foundation

protocol DirectJourneyRouter: Sendable {
    func routes(for request: JourneyRequest) async -> [Journey]
}
