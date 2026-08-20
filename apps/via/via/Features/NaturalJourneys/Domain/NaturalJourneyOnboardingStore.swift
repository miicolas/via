import Foundation

@MainActor
protocol NaturalJourneyOnboardingStoring: AnyObject {
    var hasSeenOnboarding: Bool { get }
    func markOnboardingSeen()
}

@MainActor
final class UserDefaultsNaturalJourneyOnboardingStore: NaturalJourneyOnboardingStoring {
    private static let key = "naturalJourney.onboarding.seen"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasSeenOnboarding: Bool {
        defaults.bool(forKey: Self.key)
    }

    func markOnboardingSeen() {
        defaults.set(true, forKey: Self.key)
    }
}

@MainActor
final class InMemoryNaturalJourneyOnboardingStore: NaturalJourneyOnboardingStoring {
    private(set) var hasSeenOnboarding: Bool

    init(hasSeenOnboarding: Bool = false) {
        self.hasSeenOnboarding = hasSeenOnboarding
    }

    func markOnboardingSeen() {
        hasSeenOnboarding = true
    }
}
