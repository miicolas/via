import Foundation
import XCTest
@testable import Via

final class MeetupCryptoVectorTests: XCTestCase {
    func testSharedChaChaPolyVectorMatchesBackend() throws {
        let vector = try loadVector()
        let key = try XCTUnwrap(Data(base64URLEncoded: vector.key))
        let nonce = try XCTUnwrap(Data(base64URLEncoded: vector.nonce))
        let expected = try XCTUnwrap(Data(base64URLEncoded: vector.combined))
        let plaintext = Data(vector.plaintext.utf8)
        let aad = Data(vector.aad.utf8)

        let sealed = try MeetupPayloadCipher.seal(
            plaintext,
            key: key,
            authenticatedData: aad,
            nonce: nonce
        )
        XCTAssertEqual(sealed, expected)
        XCTAssertEqual(
            try MeetupPayloadCipher.open(expected, key: key, authenticatedData: aad),
            plaintext
        )
    }

    private func loadVector() throws -> Vector {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: repository.appending(path: "fixtures/meetup-crypto-vectors.json"))
        return try JSONDecoder().decode(Vector.self, from: data)
    }

    private struct Vector: Decodable {
        let key: String
        let nonce: String
        let aad: String
        let plaintext: String
        let combined: String
    }
}
