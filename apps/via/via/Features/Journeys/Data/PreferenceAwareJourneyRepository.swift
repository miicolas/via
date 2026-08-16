import Foundation

final class PreferenceAwareJourneyRepository: JourneyRepository, Sendable {
    private let base: any JourneyRepository
    private let account: AccountModel

    init(base: any JourneyRepository, account: AccountModel) {
        self.base = base
        self.account = account
    }

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        var request = request
        let stored = await account.transportPreferences
        if request.preferredModes.isEmpty {
            request.preferredModes = stored.preferredModes
        }
        if request.excludedModes.isEmpty {
            request.excludedModes = stored.excludedModes
        }
        return try await base.plan(request)
    }
}
