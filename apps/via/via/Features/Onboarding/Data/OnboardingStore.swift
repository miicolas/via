import Foundation
import Observation

struct OnboardingStore {
    static let completionKey = "via.onboarding.completed.v3"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isCompleted: Bool {
        defaults.bool(forKey: Self.completionKey)
    }

    func markCompleted() {
        defaults.set(true, forKey: Self.completionKey)
    }

    func reset() {
        defaults.removeObject(forKey: Self.completionKey)
    }
}

@MainActor
@Observable
final class OnboardingModel {
    private(set) var isCompleted: Bool

    @ObservationIgnored private let store: OnboardingStore

    init(store: OnboardingStore = OnboardingStore()) {
        self.store = store
        isCompleted = store.isCompleted
    }

    func complete() {
        guard !isCompleted else { return }
        store.markCompleted()
        isCompleted = true
    }

    func reset() {
        store.reset()
        isCompleted = false
    }
}
