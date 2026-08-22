import Foundation
import UserNotifications
import XCTest
@testable import Via

@MainActor
final class NotificationAuthorizationTests: XCTestCase {
    /// iOS shows the alert once per install. Asking again after a refusal must not
    /// pretend the prompt is still available — the caller has to be told to send
    /// the traveller to Settings instead.
    func testDeniedStatusIsReportedWithoutAskingAgain() async {
        let center = FakeNotificationCenter(status: .denied)
        let granted = await NotificationAuthorization.request(
            center: center,
            push: PushNotificationManager.preview
        )
        XCTAssertFalse(granted)
        XCTAssertEqual(center.requestCount, 0)
    }

    func testUndeterminedStatusRaisesThePromptOnce() async {
        let center = FakeNotificationCenter(status: .notDetermined, grants: true)
        let granted = await NotificationAuthorization.request(
            center: center,
            push: PushNotificationManager.preview
        )
        XCTAssertTrue(granted)
        XCTAssertEqual(center.requestCount, 1)
    }

    /// An already-authorized install still routes through here, because that is
    /// what hands the grant to `PushNotificationManager` and registers the token.
    func testAuthorizedStatusSkipsThePromptAndStillReportsGranted() async {
        let center = FakeNotificationCenter(status: .authorized)
        let granted = await NotificationAuthorization.request(
            center: center,
            push: PushNotificationManager.preview
        )
        XCTAssertTrue(granted)
        XCTAssertEqual(center.requestCount, 0)
    }

    func testDeclinedPromptIsReportedAsNotGranted() async {
        let center = FakeNotificationCenter(status: .notDetermined, grants: false)
        let granted = await NotificationAuthorization.request(
            center: center,
            push: PushNotificationManager.preview
        )
        XCTAssertFalse(granted)
        XCTAssertEqual(center.requestCount, 1)
    }
}

@MainActor
private final class FakeNotificationCenter: JourneyNotificationCenterClient {
    private let status: UNAuthorizationStatus
    private let grants: Bool
    private(set) var requestCount = 0

    init(status: UNAuthorizationStatus, grants: Bool = false) {
        self.status = status
        self.grants = grants
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        return grants
    }

    func add(_ request: UNNotificationRequest) async throws {}
    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
}
