import XCTest
@testable import Via

final class OnboardingProfileModelTests: XCTestCase {
    @MainActor
    func testAnswersAreRequiredAndPersisted() {
        let store = InMemoryOnboardingProfileStore()
        let model = OnboardingProfileModel(store: store)

        XCTAssertFalse(model.save())

        model.selectedPass = .navigoMonthlyOrWeekly
        model.selectedPresence = .visitor
        model.selectedFrequency = .occasional

        XCTAssertTrue(model.save())
        XCTAssertEqual(
            model.savedAnswers,
            OnboardingProfileAnswers(
                pass: .navigoMonthlyOrWeekly,
                presence: .visitor,
                frequency: .occasional
            )
        )
    }

    @MainActor
    func testStoredAnswersRestoreDraftSelections() {
        let answers = OnboardingProfileAnswers(
            pass: .imagineR,
            presence: .resident,
            frequency: .daily
        )
        let model = OnboardingProfileModel(
            store: InMemoryOnboardingProfileStore(answers: answers)
        )

        XCTAssertEqual(model.selectedPass, .imagineR)
        XCTAssertEqual(model.selectedPresence, .resident)
        XCTAssertEqual(model.selectedFrequency, .daily)
    }

    func testUserDefaultsStoreRoundTripsAnswers() throws {
        let suiteName = "dev.via.onboarding-profile-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let answers = OnboardingProfileAnswers(
            pass: .navigoAnnual,
            presence: .both,
            frequency: .regular
        )
        let store = UserDefaultsOnboardingProfileStore(defaults: defaults)

        try store.save(answers)

        XCTAssertEqual(try store.load(), answers)
    }
}
