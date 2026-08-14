import XCTest

@MainActor
final class ViaUITests: XCTestCase {
    func testStationSearchOpensDepartures() {
        let app = XCUIApplication()
        app.launchArguments = ["--via-demo"]
        app.launch()

        let searchField = app.textFields["via.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))

        searchField.tap()
        searchField.typeText("Chatelet")

        let result = app.buttons["via.searchResult.demo:chatelet"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        result.tap()

        XCTAssertTrue(
            app.staticTexts["via.stationDetail.demo:chatelet"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["Prochains passages"].waitForExistence(timeout: 10))

        let planButton = app.buttons["via.planJourney"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10))
        planButton.tap()

        let walkingJourney = app.buttons["via.journey.demo:walk:demo:chatelet"]
        XCTAssertTrue(walkingJourney.waitForExistence(timeout: 10))
        walkingJourney.tap()
        XCTAssertTrue(app.staticTexts["Détail du trajet"].waitForExistence(timeout: 10))
    }

    func testChatStreamsAReplyAndPublishesAnItinerary() {
        let app = XCUIApplication()
        app.launchArguments = ["--via-demo"]
        app.launch()

        let openChat = app.buttons["via.openChat"]
        XCTAssertTrue(openChat.waitForExistence(timeout: 10))
        openChat.tap()

        let suggestion = app.buttons["via.chat.suggestion.chatelet"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10))
        suggestion.tap()

        let itinerary = app.buttons["via.chat.openItinerary"]
        XCTAssertTrue(itinerary.waitForExistence(timeout: 10))
        itinerary.tap()
        XCTAssertTrue(app.staticTexts["Détail du trajet"].waitForExistence(timeout: 10))
    }
}
