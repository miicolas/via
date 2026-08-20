import FoundationModels
import XCTest

final class FoundationModelsSmokeTests: XCTestCase {
    func testMinimalRequestCompletes() async throws {
        try XCTSkipUnless(
            SystemLanguageModel.default.availability == .available,
            "Foundation Models indisponible dans cet environnement",
        )

        let session = LanguageModelSession()
        _ = try await session.respond(to: "List all states of USA.")
    }
}
