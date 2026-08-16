import XCTest
@testable import Via

final class AuthenticationTests: XCTestCase {
    func testNonceHashMatchesAppleRequestFormat() {
        XCTAssertEqual(
            AppleSignInNonce.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testGeneratedNoncesAreRandomAndThirtyTwoCharacters() throws {
        let first = try AppleSignInNonce.generate()
        let second = try AppleSignInNonce.generate()

        XCTAssertEqual(first.count, 32)
        XCTAssertEqual(second.count, 32)
        XCTAssertNotEqual(first, second)
    }

    func testAvatarUsesTwoInitialsAndFallsBackWhenNameIsMissing() {
        XCTAssertEqual(user(name: "Camille Martin").initials, "CM")
        XCTAssertEqual(user(name: "Prince").initials, "P")
        XCTAssertNil(user(name: "").initials)
    }

    private func user(name: String) -> AuthUser {
        AuthUser(
            id: "user",
            appleUserIdentifier: "apple",
            name: name,
            email: "user@example.com"
        )
    }
}
