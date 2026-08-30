@testable import Via

/// Journey-planning double shared by the search and natural-dialogue tests:
/// replays queued responses and records every request it received.
actor JourneyRepositoryRecorder: JourneyRepository {
    private var queuedResponses: [Result<JourneyResult, ViaError>]
    private(set) var recordedRequests: [JourneyRequest] = []

    init(result: JourneyResult) {
        queuedResponses = [.success(result)]
    }

    init(responses: [Result<JourneyResult, ViaError>]) {
        queuedResponses = responses
    }

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        recordedRequests.append(request)
        let response = queuedResponses.count > 1 ? queuedResponses.removeFirst() : queuedResponses[0]
        return try response.get()
    }

    func requests() -> [JourneyRequest] { recordedRequests }
}
