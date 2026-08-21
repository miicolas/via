import Foundation
import Observation

struct OnboardingStore {
    static let completionKey = "via.onboarding.completed.v3"
    static let setupCompletionKey = "metyro.onboarding.setup.completed.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isCompleted: Bool {
        defaults.bool(forKey: Self.completionKey)
    }

    var isSetupCompleted: Bool {
        defaults.bool(forKey: Self.setupCompletionKey)
    }

    func markCompleted() {
        defaults.set(true, forKey: Self.completionKey)
    }

    func markSetupCompleted() {
        defaults.set(true, forKey: Self.setupCompletionKey)
    }

    func reset() {
        defaults.removeObject(forKey: Self.completionKey)
        defaults.removeObject(forKey: Self.setupCompletionKey)
    }
}

@MainActor
@Observable
final class OnboardingModel {
    private(set) var isCompleted: Bool
    private(set) var isSetupCompleted: Bool

    @ObservationIgnored private let store: OnboardingStore

    init(store: OnboardingStore = OnboardingStore()) {
        self.store = store
        isCompleted = store.isCompleted
        isSetupCompleted = store.isSetupCompleted
    }

    func complete() {
        guard !isCompleted else { return }
        store.markCompleted()
        isCompleted = true
    }

    func completeSetup() {
        guard !isSetupCompleted else { return }
        store.markSetupCompleted()
        isSetupCompleted = true
    }

    func reset() {
        store.reset()
        isCompleted = false
        isSetupCompleted = false
    }
}
