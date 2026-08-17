import XCTest
@testable import Via

final class OnboardingModelTests: XCTestCase {
    func testUsesVersionTwoCompletionKey() {
        XCTAssertEqual(
            OnboardingStore.completionKey,
            "via.onboarding.completed.v2"
        )
    }

    @MainActor
    func testMissingPreferenceRequiresOnboarding() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let model = OnboardingModel(store: OnboardingStore(defaults: defaults))

        XCTAssertFalse(model.isCompleted)
        XCTAssertNil(defaults.object(forKey: OnboardingStore.completionKey))
    }

    @MainActor
    func testCompletionPersistsAndRestores() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = OnboardingStore(defaults: defaults)
        let model = OnboardingModel(store: store)
        model.complete()

        XCTAssertTrue(model.isCompleted)
        XCTAssertTrue(OnboardingModel(store: store).isCompleted)
    }

    @MainActor
    func testSkipUsesTheSameCompletionState() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let model = OnboardingModel(store: OnboardingStore(defaults: defaults))
        model.skip()

        XCTAssertTrue(model.isCompleted)
    }

    @MainActor
    func testResetClearsCurrentAndPersistedState() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = OnboardingStore(defaults: defaults)
        let model = OnboardingModel(store: store)
        model.complete()
        model.reset()

        XCTAssertFalse(model.isCompleted)
        XCTAssertFalse(OnboardingModel(store: store).isCompleted)
        XCTAssertNil(defaults.object(forKey: OnboardingStore.completionKey))
    }

    @MainActor
    func testStoresAreIsolatedPerUserDefaultsSuite() {
        let (firstDefaults, firstSuiteName) = makeDefaults()
        let (secondDefaults, secondSuiteName) = makeDefaults()
        defer {
            firstDefaults.removePersistentDomain(forName: firstSuiteName)
            secondDefaults.removePersistentDomain(forName: secondSuiteName)
        }

        OnboardingModel(store: OnboardingStore(defaults: firstDefaults)).complete()

        XCTAssertTrue(OnboardingModel(store: OnboardingStore(defaults: firstDefaults)).isCompleted)
        XCTAssertFalse(OnboardingModel(store: OnboardingStore(defaults: secondDefaults)).isCompleted)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "dev.via.onboarding-tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }
}
