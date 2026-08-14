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
    }
}
