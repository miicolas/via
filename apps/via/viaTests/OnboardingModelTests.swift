import XCTest
@testable import Via

final class OnboardingModelTests: XCTestCase {
    func testUsesVersionThreeCompletionKey() {
        XCTAssertEqual(
            OnboardingStore.completionKey,
            "via.onboarding.completed.v3"
        )
    }

    func testUsesASeparateSetupCompletionKey() {
        XCTAssertEqual(
            OnboardingStore.setupCompletionKey,
            "metyro.onboarding.setup.completed.v1"
        )
    }

    @MainActor
    func testMissingPreferenceRequiresOnboarding() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let model = OnboardingModel(store: OnboardingStore(defaults: defaults))

        XCTAssertFalse(model.isCompleted)
        XCTAssertFalse(model.isSetupCompleted)
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
        XCTAssertFalse(model.isSetupCompleted)
        XCTAssertTrue(OnboardingModel(store: store).isCompleted)
    }

    @MainActor
    func testSetupCompletionPersistsSeparatelyFromPresentation() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = OnboardingStore(defaults: defaults)
        let model = OnboardingModel(store: store)
        model.complete()
        model.completeSetup()

        let restored = OnboardingModel(store: store)
        XCTAssertTrue(restored.isCompleted)
        XCTAssertTrue(restored.isSetupCompleted)
    }

    @MainActor
    func testVersionTwoCompletionDoesNotCompleteVersionThreeOnboarding() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: "via.onboarding.completed.v2")
        let model = OnboardingModel(store: OnboardingStore(defaults: defaults))

        XCTAssertFalse(model.isCompleted)
    }

    @MainActor
    func testResetClearsCurrentAndPersistedState() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = OnboardingStore(defaults: defaults)
        let model = OnboardingModel(store: store)
        model.complete()
        model.completeSetup()
        model.reset()

        XCTAssertFalse(model.isCompleted)
        XCTAssertFalse(model.isSetupCompleted)
        XCTAssertFalse(OnboardingModel(store: store).isCompleted)
        XCTAssertFalse(OnboardingModel(store: store).isSetupCompleted)
        XCTAssertNil(defaults.object(forKey: OnboardingStore.completionKey))
        XCTAssertNil(defaults.object(forKey: OnboardingStore.setupCompletionKey))
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
