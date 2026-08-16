import Foundation

final class PreferenceAwareJourneyRepository: JourneyRepository, @unchecked Sendable {
    private let base: any JourneyRepository
    private let preferences: any TransportPreferencesRepository

    init(base: any JourneyRepository, preferences: any TransportPreferencesRepository) {
        self.base = base
        self.preferences = preferences
    }

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        var request = request
        let stored = preferences.load()
        if request.preferredModes.isEmpty {
            request.preferredModes = stored.preferredModes
        }
        if request.excludedModes.isEmpty {
            request.excludedModes = stored.excludedModes
        }
        return try await base.plan(request)
    }
}
