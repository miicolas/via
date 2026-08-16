import XCTest
import HTTPTypes
import OpenAPIRuntime
@testable import Via

final class ViaTransportTests: XCTestCase {
    func testBearerMiddlewareAddsSessionRefreshesBearerAndPublishesUnauthorized() async throws {
        let vault = InMemoryAuthSessionVault(session: storedSession(bearer: "old.token"))
        let recorder = TransportRecorder()
        let middleware = BearerAuthenticationMiddleware(
            vault: vault,
            onUnauthorized: { await recorder.recordUnauthorized() }
        )
        let request = HTTPRequest(
            method: .get,
            scheme: "https",
            authority: "example.com",
            path: "/account"
        )

        _ = try await middleware.intercept(
            request,
            body: nil,
            baseURL: URL(string: "https://example.com")!,
            operationID: "account"
        ) { request, _, _ in
            await recorder.recordAuthorization(request.headerFields[.authorization])
            var response = HTTPResponse(status: .unauthorized)
            response.headerFields[HTTPField.Name("set-auth-token")!] = "new.token"
            return (response, nil)
        }

        let authorization = await recorder.authorization
        let storedBearer = try await vault.load()?.bearerToken
        let unauthorizedCount = await recorder.unauthorizedCount
        XCTAssertEqual(authorization, "Bearer old.token")
        XCTAssertEqual(storedBearer, "new.token")
        XCTAssertEqual(unauthorizedCount, 1)
    }

    func testGetRetryMiddlewareRetriesServerFailureExactlyOnce() async throws {
        let recorder = TransportRecorder()
        let middleware = IdempotentGETRetryMiddleware()
        let request = HTTPRequest(
            method: .get,
            scheme: "https",
            authority: "example.com",
            path: "/network"
        )

        let response = try await middleware.intercept(
            request,
            body: nil,
            baseURL: URL(string: "https://example.com")!,
            operationID: "network"
        ) { _, _, _ in
            let attempt = await recorder.recordAttempt()
            return (HTTPResponse(status: attempt == 1 ? .serviceUnavailable : .ok), nil)
        }

        XCTAssertEqual(response.0.status, .ok)
        let attemptCount = await recorder.attemptCount
        XCTAssertEqual(attemptCount, 2)
    }

    func testTransportMapsDocumentedStatusCodes() {
        XCTAssertEqual(ViaTransport.error(for: 401), .unauthorized)
        XCTAssertEqual(ViaTransport.error(for: 429), .rateLimited)
        XCTAssertEqual(ViaTransport.error(for: 503), .unavailable)
        XCTAssertEqual(ViaTransport.error(for: 500), .server(statusCode: 500))
    }

    private func storedSession(bearer: String) -> StoredAuthSession {
        StoredAuthSession(
            bearerToken: bearer,
            user: AuthUser(
                id: "user",
                appleUserIdentifier: "apple-user",
                name: "Camille Martin",
                email: "camille@example.com"
            ),
            expiresAt: .distantFuture,
            lastValidatedAt: .now
        )
    }
}

private actor TransportRecorder {
    private(set) var authorization: String?
    private(set) var unauthorizedCount = 0
    private(set) var attemptCount = 0

    func recordAuthorization(_ value: String?) {
        authorization = value
    }

    func recordUnauthorized() {
        unauthorizedCount += 1
    }

    func recordAttempt() -> Int {
        attemptCount += 1
        return attemptCount
    }
}
