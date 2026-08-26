import Foundation
@testable import Via
import XCTest

final class NaturalJourneyFallbackTests: XCTestCase {
    private let now = ISO8601.parse("2026-08-26T18:00:00+02:00")!

    func testServerPatchRehydratesAnOpaqueSavedPlaceWithoutPersonalCoordinatesOnTheWire() throws {
        let home = NaturalJourneySavedPlaceReference(
            id: "role:home",
            label: "Maison",
            kind: .home,
            result: .previewAddress,
        )
        let json = #"""
        {
          "outcome": "interpreted",
          "interpretation": {
            "scope": "journey",
            "origin": { "kind": "query", "value": "Auber", "evidence": "Auber" },
            "destination": { "kind": "saved", "value": "role:home", "evidence": "chez moi" },
            "originWasExplicit": true,
            "lastServiceOfDay": false,
            "timeConstraint": {
              "reference": "implicit_today", "year": 2000, "yearWasExplicit": false,
              "month": 1, "day": 1, "timePrecision": "unspecified", "hour": 0,
              "minute": 0, "relativeAmount": 0, "relativeUnit": "minute",
              "meaning": "departure", "evidence": ""
            },
            "requiredModes": [], "excludedModes": [], "preferredModes": [],
            "unsupportedConstraints": [], "unexplainedText": ""
          }
        }
        """#
        let request = NaturalIntentModelRequest(
            phrase: "rentrez chez moi depuis Auber",
            locale: Locale(identifier: "fr_FR"),
            now: now,
            hasCurrentLocation: false,
            originAnchor: nil,
            destinationAnchor: nil,
            savedPlaces: [home],
        )

        let proposal = try JSONDecoder.via
            .decode(NaturalIntentResponseDTO.self, from: Data(json.utf8))
            .proposal(for: request)

        XCTAssertEqual(proposal.intent.originPlace, .query("Auber"))
        XCTAssertEqual(proposal.intent.destinationPlace, .saved(home))
        XCTAssertEqual(proposal.originEvidence, "Auber")
        XCTAssertEqual(proposal.destinationEvidence, "chez moi")
    }

    func testServerPatchCannotInventAModeAbsentFromThePhrase() throws {
        let json = #"""
        {
          "outcome": "interpreted",
          "interpretation": {
            "scope": "journey",
            "destination": { "kind": "query", "value": "Nation", "evidence": "Nation" },
            "originWasExplicit": false,
            "lastServiceOfDay": false,
            "timeConstraint": {
              "reference": "implicit_today", "year": 2000, "yearWasExplicit": false,
              "month": 1, "day": 1, "timePrecision": "unspecified", "hour": 0,
              "minute": 0, "relativeAmount": 0, "relativeUnit": "minute",
              "meaning": "departure", "evidence": ""
            },
            "requiredModes": ["rer"], "excludedModes": [], "preferredModes": [],
            "unsupportedConstraints": [], "unexplainedText": ""
          }
        }
        """#
        let request = NaturalIntentModelRequest(
            phrase: "Va à Nation",
            locale: Locale(identifier: "fr_FR"),
            now: now,
            hasCurrentLocation: true,
            originAnchor: nil,
            destinationAnchor: nil,
            savedPlaces: [],
        )

        let dto = try JSONDecoder.via.decode(
            NaturalIntentResponseDTO.self,
            from: Data(json.utf8),
        )

        XCTAssertThrowsError(try dto.proposal(for: request)) { error in
            XCTAssertEqual(error as? NaturalIntentParsingError, .invalidResponse)
        }
    }

    func testServerPatchCannotAugmentAPlaceBeyondItsEvidence() throws {
        let json = #"""
        {
          "outcome": "interpreted",
          "interpretation": {
            "scope": "journey",
            "destination": { "kind": "query", "value": "Nation Paris", "evidence": "Nation" },
            "originWasExplicit": false,
            "lastServiceOfDay": false,
            "timeConstraint": {
              "reference": "implicit_today", "year": 2000, "yearWasExplicit": false,
              "month": 1, "day": 1, "timePrecision": "unspecified", "hour": 0,
              "minute": 0, "relativeAmount": 0, "relativeUnit": "minute",
              "meaning": "departure", "evidence": ""
            },
            "requiredModes": [], "excludedModes": [], "preferredModes": [],
            "unsupportedConstraints": [], "unexplainedText": ""
          }
        }
        """#
        let request = NaturalIntentModelRequest(
            phrase: "Va à Nation",
            locale: Locale(identifier: "fr_FR"),
            now: now,
            hasCurrentLocation: true,
            originAnchor: nil,
            destinationAnchor: nil,
            savedPlaces: [],
        )

        let dto = try JSONDecoder.via.decode(
            NaturalIntentResponseDTO.self,
            from: Data(json.utf8),
        )

        XCTAssertThrowsError(try dto.proposal(for: request)) { error in
            XCTAssertEqual(error as? NaturalIntentParsingError, .invalidResponse)
        }
    }

    func testServerPatchPreservesOnlyAnAppAnchoredConversationReference() throws {
        let json = #"""
        {
          "outcome": "interpreted",
          "interpretation": {
            "scope": "journey",
            "destination": {
              "kind": "context_reference",
              "value": "uniquely_confirmed_place",
              "evidence": "there"
            },
            "originWasExplicit": false,
            "lastServiceOfDay": false,
            "timeConstraint": {
              "reference": "implicit_today", "year": 2000, "yearWasExplicit": false,
              "month": 1, "day": 1, "timePrecision": "unspecified", "hour": 0,
              "minute": 0, "relativeAmount": 0, "relativeUnit": "minute",
              "meaning": "departure", "evidence": ""
            },
            "requiredModes": [], "excludedModes": [], "preferredModes": [],
            "unsupportedConstraints": [], "unexplainedText": ""
          }
        }
        """#
        let anchor = NaturalIntentModelAnchor(
            place: .reference(.uniquelyConfirmedPlace),
            evidence: "there",
        )
        let request = NaturalIntentModelRequest(
            phrase: "go there",
            locale: Locale(identifier: "en_US"),
            now: now,
            hasCurrentLocation: true,
            originAnchor: nil,
            destinationAnchor: anchor,
            savedPlaces: [],
        )
        let dto = try JSONDecoder.via.decode(
            NaturalIntentResponseDTO.self,
            from: Data(json.utf8),
        )

        let proposal = try dto.proposal(for: request)

        XCTAssertEqual(
            proposal.intent.destinationPlace,
            .reference(.uniquelyConfirmedPlace),
        )
    }

    func testTechnicalLocalFailureUsesTheServerInterpreterWhenAllowed() async throws {
        let localCalls = NaturalIntentParserCallRecorder()
        let remoteCalls = NaturalIntentParserCallRecorder()
        let expected = intent(destination: "Nation")
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: RecordingNaturalIntentParser(
                calls: localCalls,
                result: .failure(.modelBusy),
            ),
            remoteModel: RecordingNaturalIntentParser(
                calls: remoteCalls,
                result: .success(NaturalIntentProposal(intent: expected)),
            ),
            savedPlaces: { [] },
            serverFallbackAllowed: { true },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "Je voudrais me rendre quelque part à Nation",
                locale: Locale(identifier: "fr_FR"),
                now: now,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.destinationQuery, "Nation")
        let localCount = await localCalls.count
        let remoteCount = await remoteCalls.count
        XCTAssertEqual(localCount, 1)
        XCTAssertEqual(remoteCount, 1)
    }

    func testServerUnavailableOutcomeIsNotADeviceFailure() throws {
        let json = #"{ "outcome": "unavailable", "message": "Réessaie dans un instant." }"#
        let request = NaturalIntentModelRequest(
            phrase: "Va à Nation",
            locale: Locale(identifier: "fr_FR"),
            now: now,
            hasCurrentLocation: true,
            originAnchor: nil,
            destinationAnchor: nil,
            savedPlaces: [],
        )

        let dto = try JSONDecoder.via.decode(
            NaturalIntentResponseDTO.self,
            from: Data(json.utf8),
        )

        XCTAssertThrowsError(try dto.proposal(for: request)) { error in
            XCTAssertEqual(error as? NaturalIntentParsingError, .remoteUnavailable)
        }
    }

    func testRemoteUnavailabilitySurfacesTheLocalDiagnosis() async throws {
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: RecordingNaturalIntentParser(
                calls: NaturalIntentParserCallRecorder(),
                result: .failure(.modelNotReady),
            ),
            remoteModel: RecordingNaturalIntentParser(
                calls: NaturalIntentParserCallRecorder(),
                result: .failure(.remoteUnavailable),
            ),
            savedPlaces: { [] },
            serverFallbackAllowed: { true },
        )

        do {
            _ = try await understanding.interpret(
                NaturalJourneyTurn(
                    phrase: "Je voudrais me rendre quelque part à Nation",
                    locale: Locale(identifier: "fr_FR"),
                    now: now,
                ),
                state: nil,
            )
            XCTFail("L’indisponibilité serveur doit rendre le diagnostic local")
        } catch let error as NaturalIntentParsingError {
            XCTAssertEqual(error, .modelNotReady)
        }
    }

    func testSafetyRefusalNeverFallsBackToTheServer() async throws {
        let remoteCalls = NaturalIntentParserCallRecorder()
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: RecordingNaturalIntentParser(
                calls: NaturalIntentParserCallRecorder(),
                result: .failure(.contentRefused),
            ),
            remoteModel: RecordingNaturalIntentParser(
                calls: remoteCalls,
                result: .success(NaturalIntentProposal(intent: intent(destination: "Nation"))),
            ),
            savedPlaces: { [] },
            serverFallbackAllowed: { true },
        )

        do {
            _ = try await understanding.interpret(
                NaturalJourneyTurn(phrase: "Demande refusée vers Nation", now: now),
                state: nil,
            )
            XCTFail("Le refus local doit rester terminal")
        } catch let error as NaturalIntentParsingError {
            XCTAssertEqual(error, .contentRefused)
        }
        let remoteCount = await remoteCalls.count
        XCTAssertEqual(remoteCount, 0)
    }

    private func intent(destination: String) -> RouteIntent {
        RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: destination,
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: false,
        )
    }
}

private actor NaturalIntentParserCallRecorder {
    private(set) var count = 0
    func record() { count += 1 }
}

private struct RecordingNaturalIntentParser: NaturalIntentParsing {
    let calls: NaturalIntentParserCallRecorder
    let result: Result<NaturalIntentProposal, NaturalIntentParsingError>

    var availability: NaturalLanguageAvailability { .available }

    func proposeIntent(
        _: NaturalIntentModelRequest
    ) async throws(NaturalIntentParsingError) -> NaturalIntentProposal {
        await calls.record()
        return try result.get()
    }
}
