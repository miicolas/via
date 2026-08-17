import XCTest
@testable import Via

final class MotionPolicyTests: XCTestCase {
    func testReduceMotionDisablesBeamAnimation() {
        XCTAssertFalse(MotionPolicy.beamEnabled(reduceMotion: true))
        XCTAssertTrue(MotionPolicy.beamEnabled(reduceMotion: false))
    }
}
