import Foundation
import XCTest
@testable import Via

final class PushNotificationTests: XCTestCase {
    func testAPNsTokensUseLowercaseHexWithoutSeparators() {
        XCTAssertEqual(
            PushNotificationManager.hexToken(Data([0x00, 0x0F, 0xA0, 0xFF])),
            "000fa0ff"
        )
    }
}
