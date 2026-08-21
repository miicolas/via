import Foundation
import Observation

protocol OnboardingProfileStoring: Sendable {
    func load() throws -> OnboardingProfileAnswers?
    func save(_ answers: OnboardingProfileAnswers) throws
    func clear() throws
}

final class UserDefaultsOnboardingProfileStore: OnboardingProfileStoring, @unchecked Sendable {
    static let storageKey = "metyro.onboarding.profile.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> OnboardingProfileAnswers? {
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try JSONDecoder().decode(OnboardingProfileAnswers.self, from: data)
    }

    func save(_ answers: OnboardingProfileAnswers) throws {
        defaults.set(try JSONEncoder().encode(answers), forKey: Self.storageKey)
    }

    func clear() throws {
        defaults.removeObject(forKey: Self.storageKey)
    }
}

final class InMemoryOnboardingProfileStore: OnboardingProfileStoring, @unchecked Sendable {
    private var answers: OnboardingProfileAnswers?

    init(answers: OnboardingProfileAnswers? = nil) {
        self.answers = answers
    }

    func load() throws -> OnboardingProfileAnswers? { answers }
    func save(_ answers: OnboardingProfileAnswers) throws { self.answers = answers }
    func clear() throws { answers = nil }
}

@MainActor
@Observable
final class OnboardingProfileModel {
    var selectedPass: TransitPassKind?
    var selectedPresence: IleDeFrancePresence?
    var selectedFrequency: TransitUsageFrequency?
    private(set) var savedAnswers: OnboardingProfileAnswers?
    private(set) var errorMessage: String?

    @ObservationIgnored private let store: any OnboardingProfileStoring

    init(store: any OnboardingProfileStoring = UserDefaultsOnboardingProfileStore()) {
        self.store = store
        errorMessage = nil

        do {
            let answers = try store.load()
            savedAnswers = answers
            selectedPass = answers?.pass
            selectedPresence = answers?.presence
            selectedFrequency = answers?.frequency
        } catch {
            savedAnswers = nil
            selectedPass = nil
            selectedPresence = nil
            selectedFrequency = nil
            errorMessage = "Tes réponses n’ont pas pu être chargées. Tu peux continuer."
        }
    }

    var canSave: Bool {
        selectedPass != nil && selectedPresence != nil && selectedFrequency != nil
    }

    @discardableResult
    func save() -> Bool {
        guard let selectedPass, let selectedPresence, let selectedFrequency else {
            errorMessage = "Choisis une réponse à chaque question pour continuer."
            return false
        }

        let answers = OnboardingProfileAnswers(
            pass: selectedPass,
            presence: selectedPresence,
            frequency: selectedFrequency
        )

        do {
            try store.save(answers)
            savedAnswers = answers
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Tes réponses n’ont pas pu être enregistrées. Réessaie."
            return false
        }
    }

    func clear() {
        try? store.clear()
        savedAnswers = nil
        selectedPass = nil
        selectedPresence = nil
        selectedFrequency = nil
        errorMessage = nil
    }
}
