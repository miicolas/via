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

struct AppleMapsDirectionsTests {
    @Test
    func buildsPublicTransitDirectionsURLFromDestinationCoordinate() throws {
        let url = try #require(
            appleMapsDirectionsURL(
                to: GeoCoordinate(latitude: 48.8584, longitude: 2.3470)
            )
        )
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(
            uniqueKeysWithValues: components.queryItems?.map { ($0.name, $0.value) } ?? []
        )

        #expect(components.scheme == "http")
        #expect(components.host == "maps.apple.com")
        #expect(query["daddr"] == "48.8584,2.347")
        #expect(query["dirflg"] == "r")
    }
}

struct RecentSearchTests {
    @Test
    func remembersWhitelistedEntriesMostRecentlyUsedFirst() throws {
        let first = SearchResult.station(
            StationSearchResult(
                id: "station-1",
                name: "Châtelet",
                coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3470),
                routes: [],
                distanceMeters: 42
            )
        )
        let second = SearchResult.address(
            AddressSearchResult(
                id: "address-1",
                name: "Louvre",
                context: "Paris",
                coordinate: GeoCoordinate(latitude: 48.8607, longitude: 2.3376),
                distanceMeters: 128
            )
        )

        let entries = rememberRecentSearches(
            rememberRecentSearches([], result: first),
            result: second
        )
        let refreshed = rememberRecentSearches(entries, result: first)

        #expect(refreshed.map(recentSearchKey) == ["station:station-1", "address:address-1"])
        #expect(refreshed.first?.coordinate == first.coordinate)
        if case .station(let station) = refreshed.first {
            #expect(station.distanceMeters == nil)
        } else {
            Issue.record("Expected a station snapshot")
        }
    }

    @Test
    func versionedStorageRoundTripsAndRejectsUnknownVersions() throws {
        let entry = SearchResult.station(
            StationSearchResult(
                id: "station-1",
                name: "Châtelet",
                coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3470),
                routes: [],
                distanceMeters: nil
            )
        )
        let data = try #require(serializeRecentSearches([entry]))

        #expect(parseRecentSearches(data) == [entry])
        #expect(parseRecentSearches(Data(#"{"version":99,"entries":[]}"#.utf8)).isEmpty)
        #expect(parseRecentSearches(Data("not-json".utf8)).isEmpty)
    }
}

struct NaturalJourneyModelTests {
    @MainActor
    @Test
    func featureModelOwnsRequestLifecycleAndPublishesDomainState() async throws {
        let model = NaturalJourneyModel(transitAPI: DemoTransitAPI())
        var states: [NaturalJourneyState] = []
        model.onStateChange = { states.append($0) }

        model.submit(
            "Comment aller à Châtelet ?",
            currentLocation: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        )
        try await Task.sleep(for: .milliseconds(600))

        #expect(states.first == .interpreting)
        guard case .ready(let ready) = model.state else {
            Issue.record("Expected the feature model to publish a ready state")
            return
        }
        #expect(ready.interpretation.destination.name == "Châtelet")
    }

    @Test
    func demoAdapterResolvesARecognizedDestination() async throws {
        let response = try await DemoTransitAPI().submitNaturalJourney(
            .submit(
                query: "Comment aller à Châtelet ?",
                currentLocation: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
            )
        )

        guard case .ready(let ready) = response else {
            Issue.record("Expected the demo adapter to resolve Châtelet")
            return
        }
        #expect(ready.interpretation.destination.name == "Châtelet")
        #expect(ready.journeys.journeys.isEmpty == false)
    }

    @Test
    func demoAdapterReturnsCandidatesWhenDestinationIsUnknown() async throws {
        let response = try await DemoTransitAPI().submitNaturalJourney(
            .submit(query: "Comment aller au musée ?", currentLocation: nil)
        )

        guard case .needsClarification(let clarification) = response else {
            Issue.record("Expected the demo adapter to ask for a destination")
            return
        }
        #expect(clarification.fields.first?.target == .destination)
        #expect(clarification.fields.first?.candidates.isEmpty == false)
    }

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
