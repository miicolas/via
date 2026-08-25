import Foundation
import XCTest

@testable import Via

final class NaturalJourneyFallbackTests: XCTestCase {

  // MARK: - Wire decoding

  func testReadyOutcomeDecodesToReadyResult() throws {
    let json = #"""
    {
      "outcome": "ready",
      "interpretation": {
        "originLabel": "Ma position",
        "destination": {
          "kind": "station",
          "id": "chatelet",
          "name": "Châtelet",
          "coordinate": { "latitude": 48.8586, "longitude": 2.3475 }
        },
        "destinationResult": {
          "kind": "station",
          "id": "chatelet",
          "name": "Châtelet",
          "coordinate": { "latitude": 48.8586, "longitude": 2.3475 },
          "routes": []
        },
        "requestedAt": "2026-08-25T09:00:00+02:00",
        "datetimeRepresents": "arrival",
        "requiredModes": ["metro"],
        "excludedModes": [],
        "preferredModes": []
      },
      "journeys": {
        "status": "ready",
        "source": "idfm-realtime",
        "generatedAt": "2026-08-25T08:00:00+02:00",
        "journeys": []
      }
    }
    """#

    let result = try JSONDecoder.via
      .decode(NaturalJourneyResponseDTO.self, from: Data(json.utf8))
      .domain()

    guard case .ready(let interpretation, let journeys) = result else {
      return XCTFail("Expected .ready, got \(result)")
    }
    XCTAssertEqual(interpretation.originLabel, "Ma position")
    XCTAssertNil(interpretation.originResult)
    XCTAssertEqual(interpretation.destinationResult.name, "Châtelet")
    XCTAssertEqual(interpretation.datetimeRepresents, .arrival)
    XCTAssertEqual(interpretation.requiredModes, [.metro])
    XCTAssertEqual(journeys.journeys.count, 0)
  }

  func testUnsupportedOutcomeDecodes() throws {
    let json = #"""
    {
      "outcome": "unsupported",
      "message": "Metyro ne comprend pas cette demande.",
      "examples": ["Châtelet demain avant 9 h"]
    }
    """#

    let result = try JSONDecoder.via
      .decode(NaturalJourneyResponseDTO.self, from: Data(json.utf8))
      .domain()

    XCTAssertEqual(
      result,
      .unsupported(
        message: "Metyro ne comprend pas cette demande.",
        examples: ["Châtelet demain avant 9 h"]
      )
    )
  }

  func testUnavailableOutcomeDecodes() throws {
    let json = #"""
    { "outcome": "unavailable", "message": "Momentanément indisponible." }
    """#

    let result = try JSONDecoder.via
      .decode(NaturalJourneyResponseDTO.self, from: Data(json.utf8))
      .domain()

    XCTAssertEqual(result, .unavailable(message: "Momentanément indisponible."))
  }

  // MARK: - Hybrid routing

  func testSubmitStaysOnDeviceWhenAvailable() async throws {
    let onDevice = RecordingNaturalJourneyRepository(result: .unsupported(message: "local", examples: []))
    let remote = RecordingNaturalJourneyRepository(result: .unsupported(message: "remote", examples: []))
    let hybrid = HybridNaturalJourneyService(
      onDevice: onDevice,
      remote: remote,
      availability: { .available }
    )

    let result = try await hybrid.submit(.submit(query: "Châtelet", currentLocation: nil))

    XCTAssertEqual(result, .unsupported(message: "local", examples: []))
    let onDeviceCallCount = await onDevice.callCount
    let remoteCallCount = await remote.callCount
    XCTAssertEqual(onDeviceCallCount, 1)
    XCTAssertEqual(remoteCallCount, 0)
  }

  func testSubmitGoesRemoteWhenUnavailable() async throws {
    let onDevice = RecordingNaturalJourneyRepository(result: .unsupported(message: "local", examples: []))
    let remote = RecordingNaturalJourneyRepository(result: .unsupported(message: "remote", examples: []))
    let hybrid = HybridNaturalJourneyService(
      onDevice: onDevice,
      remote: remote,
      availability: { .unavailable(.deviceNotEligible) }
    )

    let result = try await hybrid.submit(.submit(query: "Châtelet", currentLocation: nil))

    XCTAssertEqual(result, .unsupported(message: "remote", examples: []))
    let onDeviceCallCount = await onDevice.callCount
    let remoteCallCount = await remote.callCount
    XCTAssertEqual(onDeviceCallCount, 0)
    XCTAssertEqual(remoteCallCount, 1)
  }

  func testSubmitRescuesRemoteWhenLocalModelFails() async throws {
    let onDevice = RecordingNaturalJourneyRepository(error: NaturalIntentParsingError.modelFailed)
    let remote = RecordingNaturalJourneyRepository(result: .unsupported(message: "remote", examples: []))
    let hybrid = HybridNaturalJourneyService(
      onDevice: onDevice,
      remote: remote,
      availability: { .available }
    )

    let result = try await hybrid.submit(.submit(query: "Châtelet", currentLocation: nil))

    XCTAssertEqual(result, .unsupported(message: "remote", examples: []))
    let onDeviceCallCount = await onDevice.callCount
    let remoteCallCount = await remote.callCount
    XCTAssertEqual(onDeviceCallCount, 1)
    XCTAssertEqual(remoteCallCount, 1)
  }

  func testSubmitNeverForwardsARefusedPhrase() async throws {
    let onDevice = RecordingNaturalJourneyRepository(error: NaturalIntentParsingError.contentRefused)
    let remote = RecordingNaturalJourneyRepository(result: .unsupported(message: "remote", examples: []))
    let hybrid = HybridNaturalJourneyService(
      onDevice: onDevice,
      remote: remote,
      availability: { .available }
    )

    do {
      _ = try await hybrid.submit(.submit(query: "Châtelet", currentLocation: nil))
      XCTFail("Expected the local refusal to surface")
    } catch let error as NaturalIntentParsingError {
      XCTAssertEqual(error, .contentRefused)
    }
    let remoteCallCount = await remote.callCount
    XCTAssertEqual(remoteCallCount, 0)
  }

  func testFollowUpRequestsNeverGoRemote() async throws {
    let onDevice = RecordingNaturalJourneyRepository(result: .unsupported(message: "local", examples: []))
    let remote = RecordingNaturalJourneyRepository(result: .unsupported(message: "remote", examples: []))
    let hybrid = HybridNaturalJourneyService(
      onDevice: onDevice,
      remote: remote,
      // Even with the local model unavailable, a draft belongs on-device.
      availability: { .unavailable(.modelNotReady) }
    )

    let draft = NaturalJourneyDraft(
      intent: RouteIntent(
        scope: .journey,
        origin: .currentLocation,
        destinationQuery: "Châtelet",
        requestedAt: nil,
        datetimeRepresents: .departure,
        requiredModes: [],
        excludedModes: [],
        preferredModes: []
      ),
      origin: nil,
      destination: nil
    )
    _ = try await hybrid.submit(
      .resolve(
        draft: draft,
        currentLocation: nil,
        origin: nil,
        destination: nil,
        requestedAt: nil,
        datetimeRepresents: .departure
      ))

    let onDeviceCallCount = await onDevice.callCount
    let remoteCallCount = await remote.callCount
    XCTAssertEqual(onDeviceCallCount, 1)
    XCTAssertEqual(remoteCallCount, 0)
  }
}

/// A repository double that counts calls and answers with a canned result or
/// error, so routing through `HybridNaturalJourneyService` is observable.
private actor RecordingNaturalJourneyRepository: NaturalJourneyRepository {
  private let result: NaturalJourneyResult?
  private let error: Error?
  private(set) var callCount = 0

  init(result: NaturalJourneyResult) {
    self.result = result
    error = nil
  }

  init(error: Error) {
    result = nil
    self.error = error
  }

  func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
    callCount += 1
    if let error { throw error }
    return result!
  }
}
