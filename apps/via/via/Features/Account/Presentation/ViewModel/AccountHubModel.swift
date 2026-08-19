import Observation

/// Composition interface for the account/settings tab. The application shell
/// retains one module instead of threading account, authentication, onboarding,
/// support, and search adapters through every presentation layer.
@MainActor
@Observable
final class AccountHubModel {
    let account: AccountModel
    let authSession: AuthSessionViewModel
    let onboarding: OnboardingModel
    let supportDestinations: SupportDestinations

    @ObservationIgnored private let searchRepository: any SearchRepository

    init(
        account: AccountModel,
        authSession: AuthSessionViewModel,
        onboarding: OnboardingModel,
        supportDestinations: SupportDestinations,
        searchRepository: any SearchRepository
    ) {
        self.account = account
        self.authSession = authSession
        self.onboarding = onboarding
        self.supportDestinations = supportDestinations
        self.searchRepository = searchRepository
    }

    func restoreSession() async {
        await authSession.restore()
    }

    func sceneBecameActive() async {
        await authSession.sceneBecameActive()
    }

    func searchPlaces(query: String) async throws -> SearchResponse {
        try await searchRepository.search(query: query, near: nil)
    }
}
