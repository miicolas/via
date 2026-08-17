import XCTest
@testable import Via

final class HybridNaturalJourneyRepositoryTests: XCTestCase {
    func testAvailableModelUsesOnDeviceResultWithoutCallingServer() async throws {
        let expected = NaturalJourneyResult.unsupported(message: "local", examples: [])
        let remote = HybridRepositoryRecorder(result: .unsupported(message: "remote", examples: []))
        let hybrid = HybridNaturalJourneyRepository(
            parser: InMemoryNaturalIntentParser(),
            onDevice: HybridRepositoryStub(result: .success(expected)),
            remote: remote
        )

        let result = try await hybrid.submit(.submit(query: "Nation", currentLocation: nil))

        XCTAssertEqual(result, expected)
        let requestCount = await remote.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testModelGenerationFailureFallsBackSilentlyToServer() async throws {
        let expected = NaturalJourneyResult.unsupported(message: "remote", examples: [])
        let remote = HybridRepositoryRecorder(result: expected)
        let hybrid = HybridNaturalJourneyRepository(
            parser: InMemoryNaturalIntentParser(),
            onDevice: HybridRepositoryStub(result: .failure(.modelBusy)),
            remote: remote
        )

        let result = try await hybrid.submit(.submit(query: "Nation", currentLocation: nil))

        XCTAssertEqual(result, expected)
        let requestCount = await remote.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testUnavailableModelSendsResolveRequestDirectlyToServer() async throws {
        let expected = NaturalJourneyResult.unsupported(message: "remote", examples: [])
        let remote = HybridRepositoryRecorder(result: expected)
        let parser = InMemoryNaturalIntentParser(
            availability: .unavailable(.deviceNotEligible)
        )
        let request = NaturalJourneyRequest.resolve(
            draft: .init(
                intent: .init(
                    scope: .journey,
                    origin: .currentLocation,
                    destinationQuery: nil,
                    requestedAt: nil,
                    datetimeRepresents: .departure,
                    requiredModes: [], excludedModes: [], preferredModes: []
                ),
                origin: nil,
                destination: nil
            ),
            currentLocation: nil,
            origin: nil,
            destination: nil,
            datetimeRepresents: .arrival
        )
        let hybrid = HybridNaturalJourneyRepository(
            parser: parser,
            onDevice: HybridRepositoryStub(result: .failure(.modelFailed)),
            remote: remote
        )

        _ = try await hybrid.submit(request)

        let requests = await remote.requests
        XCTAssertEqual(requests, [request])
    }

    func testDoubleFailureExplainsActionableAppleIntelligenceState() async throws {
        let parser = InMemoryNaturalIntentParser(
            availability: .unavailable(.appleIntelligenceDisabled)
        )
        let remote = HybridRepositoryRecorder(error: .transport)
        let hybrid = HybridNaturalJourneyRepository(
            parser: parser,
            onDevice: HybridRepositoryStub(result: .failure(.modelFailed)),
            remote: remote
        )

        let result = try await hybrid.submit(.submit(query: "Nation", currentLocation: nil))

        XCTAssertEqual(
            result,
            .unavailable(
                message: "Active Apple Intelligence pour utiliser la recherche en langage naturel lorsque le serveur est indisponible.",
                guidance: .enableAppleIntelligence
            )
        )
    }

    func testOnDeviceTransportFailureIsRethrownWithoutCallingServer() async {
        let remote = HybridRepositoryRecorder(result: .unsupported(message: "remote", examples: []))
        let hybrid = HybridNaturalJourneyRepository(
            parser: InMemoryNaturalIntentParser(),
            onDevice: HybridRepositoryStub(error: .transport),
            remote: remote
        )

        do {
            _ = try await hybrid.submit(.submit(query: "Nation", currentLocation: nil))
            XCTFail("Expected transport error")
        } catch {
            XCTAssertEqual(error as? ViaError, .transport)
        }
        let requestCount = await remote.requestCount
        XCTAssertEqual(requestCount, 0)
    }
}

private struct HybridRepositoryStub: NaturalJourneyRepository {
    let result: Result<NaturalJourneyResult, Error>

    init(result: Result<NaturalJourneyResult, NaturalIntentParsingError>) {
        self.result = result.mapError { $0 as Error }
    }

    init(error: ViaError) {
        result = .failure(error)
    }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        try result.get()
    }
}

private actor HybridRepositoryRecorder: NaturalJourneyRepository {
    private let result: NaturalJourneyResult?
    private let error: ViaError?
    private(set) var requests: [NaturalJourneyRequest] = []

    init(result: NaturalJourneyResult) {
        self.result = result
        error = nil
    }

    init(error: ViaError) {
        result = nil
        self.error = error
    }

    var requestCount: Int { requests.count }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        requests.append(request)
        if let error { throw error }
        return result!
    }
}
