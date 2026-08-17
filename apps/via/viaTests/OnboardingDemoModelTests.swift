import XCTest
@testable import Via

final class OnboardingDemoModelTests: XCTestCase {
    @MainActor
    func testStartsWithWelcomeAndPrefilledQuery() {
        let model = OnboardingDemoModel()

        XCTAssertEqual(model.phase, .welcome)
        XCTAssertEqual(model.query, "Je veux arriver à La Défense avant 9 h")
        XCTAssertNil(model.journeyPresentation)
    }

    @MainActor
    func testStartMovesFromWelcomeToInput() {
        let model = OnboardingDemoModel()

        model.start()

        XCTAssertEqual(model.phase, .input)
    }

    @MainActor
    func testSendGeneratesLocalResultAndMapPresentation() async {
        let model = OnboardingDemoModel(generationDelay: .zero)
        model.start()

        model.send()

        XCTAssertEqual(model.phase, .generating)
        await waitForResult(model)

        XCTAssertEqual(model.phase, .result)
        XCTAssertEqual(model.journeyPresentation, OnboardingDemoFixture.mapPresentation)
        XCTAssertEqual(
            model.naturalJourneyResult,
            OnboardingDemoFixture.naturalJourneyResult
        )
    }

    @MainActor
    func testSecondSendDoesNotRestartCompletedDemo() async {
        let model = OnboardingDemoModel(generationDelay: .zero)
        model.start()
        model.send()
        await waitForResult(model)

        model.send()

        XCTAssertEqual(model.phase, .result)
    }

    @MainActor
    func testSecondSendWhileGeneratingIsIgnored() async {
        let model = OnboardingDemoModel(generationDelay: .zero)
        model.start()
        model.send()
        model.send()

        XCTAssertEqual(model.phase, .generating)
        await waitForResult(model)
        XCTAssertEqual(model.phase, .result)
    }

    @MainActor
    func testResetReturnsToWelcomeAndHidesJourney() async {
        let model = OnboardingDemoModel(generationDelay: .zero)
        model.start()
        model.send()
        await waitForResult(model)

        model.reset()

        XCTAssertEqual(model.phase, .welcome)
        XCTAssertNil(model.journeyPresentation)
    }

    @MainActor
    func testFixtureAnswersForLaDefense() {
        XCTAssertEqual(OnboardingDemoFixture.destination.name, "1 Parvis de la Défense")
        XCTAssertEqual(
            OnboardingDemoFixture.journey.sections.compactMap(\.route?.shortName),
            ["A", "1"]
        )
    }

    @MainActor
    private func waitForResult(_ model: OnboardingDemoModel) async {
        for _ in 0..<100 {
            if model.phase == .result { return }
            await Task.yield()
        }

        XCTFail("La démo n’a pas atteint l’état résultat")
    }
}
