import Foundation
import Testing
@testable import Via

struct JourneyPresentationTests {
    @Test
    func mergesAdjacentWalkingSectionsAndKeepsTransitBadges() {
        let route = JourneyRoute(
            id: "line-1",
            shortName: "1",
            longName: "La Défense — Vincennes",
            mode: .metro,
            color: "FFCD00",
            textColor: "161A18"
        )
        let origin = JourneyPlace(
            name: "Départ",
            coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35)
        )
        let station = JourneyPlace(
            name: "Station",
            coordinate: GeoCoordinate(latitude: 48.86, longitude: 2.35)
        )
        let destination = JourneyPlace(
            name: "Arrivée",
            coordinate: GeoCoordinate(latitude: 48.87, longitude: 2.35)
        )
        let journey = Journey(
            id: "journey",
            qualifier: .recommended,
            durationSeconds: 900,
            walkingDurationSeconds: 240,
            transferCount: 0,
            departureAt: "2026-08-15T10:00:00+02:00",
            arrivalAt: "2026-08-15T10:15:00+02:00",
            status: .normal,
            warnings: [],
            sections: [
                JourneySection(
                    type: .walk,
                    durationSeconds: 120,
                    from: origin,
                    to: station,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
                JourneySection(
                    type: .transfer,
                    durationSeconds: 120,
                    from: station,
                    to: station,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
                JourneySection(
                    type: .transit,
                    durationSeconds: 660,
                    from: station,
                    to: destination,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: route,
                    direction: "Vincennes",
                    platform: nil,
                    stops: []
                ),
            ]
        )

        let segments = journeySegments(journey)

        #expect(segments.count == 2)
        #expect(segments[0].kind == .walk)
        #expect(segments[0].minutes == 4)
        #expect(segments[1].route?.shortName == "1")
        #expect(segments[1].minutes == 11)
    }
}

struct NaturalJourneyModelTests {
    @Test
    func submitRequestPreservesTheMinimalWireShape() throws {
        let data = try JSONEncoder().encode(
            NaturalJourneyRequest.submit(
                query: "aller à Châtelet",
                currentLocation: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
            )
        )
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["action"] as? String == "submit")
        #expect(object["query"] as? String == "aller à Châtelet")
        #expect((object["currentLocation"] as? [String: Double])?["latitude"] == 48.8566)
    }

    @Test
    func resolveRequestKeepsNullableIntentFieldsAndChosenPlace() throws {
        let draft = NaturalJourneyDraft(
            intent: NaturalJourneyIntent(
                scope: .journey,
                origin: .place(query: "République"),
                destinationQuery: "Châtelet",
                requestedAt: "2026-08-15T10:00:00+02:00",
                datetimeRepresents: .ambiguous,
                requiredModes: [.metro],
                excludedModes: [],
                preferredModes: []
            ),
            origin: nil,
            destination: nil
        )
        let result = SearchResult.station(
            StationSearchResult(
                id: "station-chatelet",
                name: "Châtelet",
                coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3470),
                routes: [],
                distanceMeters: nil
            )
        )
        let data = try JSONEncoder().encode(
            NaturalJourneyRequest.resolve(
                draft: draft,
                currentLocation: nil,
                origin: nil,
                destination: result,
                datetimeRepresents: .arrival
            )
        )
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encodedDraft = try #require(object["draft"] as? [String: Any])
        let intent = try #require(encodedDraft["intent"] as? [String: Any])

        #expect(object["action"] as? String == "resolve")
        #expect(intent["destinationQuery"] as? String == "Châtelet")
        #expect(intent["requestedAt"] as? String == "2026-08-15T10:00:00+02:00")
        #expect(object["datetimeRepresents"] as? String == "arrival")
        #expect(object["destination"] != nil)
    }

    @Test
    func decodesClarificationCandidatesAsDomainSearchResults() throws {
        let data = #"""
        {
          "status": "needs_clarification",
          "draft": {
            "intent": {
              "scope": "journey",
              "origin": { "kind": "current_location" },
              "destinationQuery": "Châtelet",
              "requestedAt": null,
              "datetimeRepresents": "arrival",
              "requiredModes": [],
              "excludedModes": [],
              "preferredModes": []
            }
          },
          "fields": [{
            "target": "destination",
            "question": "Quelle station ?",
            "candidates": [{
              "kind": "station",
              "id": "station-chatelet",
              "name": "Châtelet",
              "coordinate": { "latitude": 48.8584, "longitude": 2.3470 },
              "routes": [],
              "distanceMeters": null
            }]
          }]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder().decode(NaturalJourneyResponse.self, from: data)

        guard case .needsClarification(let clarification) = response else {
            Issue.record("Expected a clarification response")
            return
        }
        #expect(clarification.fields.first?.candidates.first?.name == "Châtelet")
        #expect(clarification.draft.intent.destinationQuery == "Châtelet")
    }
}
