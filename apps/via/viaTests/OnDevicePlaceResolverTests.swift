import XCTest
@testable import Via

final class OnDevicePlaceResolverTests: XCTestCase {
    func testPlaceKindHintsAreInferredFromSemanticWordsNotPlaceNames() {
        let transitEvidence = [
            "station RER Auber",
            "métro République",
            "arrêt de bus Hôtel de Ville",
            "gare de Lyon",
        ]
        for evidence in transitEvidence {
            XCTAssertEqual(
                NaturalPlaceKindHint.inferred(from: evidence),
                .transit,
                evidence
            )
        }
        XCTAssertEqual(
            NaturalPlaceKindHint.inferred(from: "centre-ville de Montreuil"),
            .locality
        )
        XCTAssertEqual(
            NaturalPlaceKindHint.inferred(from: "adresse de République"),
            .address
        )
        XCTAssertEqual(
            NaturalPlaceKindHint.inferred(from: "Porte de Versailles"),
            .automatic
        )
    }

    func testExactStationNameIgnoresAccentsAndDashVariants() async throws {
        let expected = station("saint-remy", "Saint-Rémy-lès-Chevreuse")
        let resolver = resolver(results: [
            address("address", "Saint Rémy les Chevreuse"),
            expected,
        ])

        let resolution = try await resolver.resolve(
            "SAINT–REMY-LES-CHEVREUSE",
            near: nil
        )

        XCTAssertEqual(resolution, .resolved(expected))
    }

    func testStationQueryPrefersAStationOverAddressSuggestions() async throws {
        let expected = station("nation", "Nation")
        let resolver = resolver(results: [
            address("place-nation", "Place de la Nation"),
            expected,
            address("avenue-nation", "Avenue de la Nation"),
        ])

        let resolution = try await resolver.resolve("Nation", near: nil)

        XCTAssertEqual(resolution, .resolved(expected))
    }

    func testChatouPrefersTheUniqueRailStationOverIncidentalBusStops() async throws {
        let expected = station("chatou-croissy", "Chatou - Croissy", modes: [.rer, .bus])
        let resolver = resolver(results: [
            expected,
            station("route-chatou", "Route de Chatou", modes: [.bus]),
            station("clemenceau-chatou", "Clémenceau / Rue de Chatou", modes: [.bus]),
            address("chatou", "Chatou"),
        ])

        let resolution = try await resolver.resolve("Chatou", near: nil)

        XCTAssertEqual(resolution, .resolved(expected))
    }

    func testExplicitTransitWordingSearchesTheCanonicalStationName() async throws {
        let expected = station("bonne-nouvelle", "Bonne Nouvelle", modes: [.metro])
        let recorder = PlaceResolverQueryRecorder(result: expected)
        let resolver = OnDevicePlaceResolver { query, _ in
            await recorder.response(for: query)
        }

        let resolution = try await resolver.resolve("station de métro Bonne Nouvelle", near: nil)

        XCTAssertEqual(resolution, .resolved(expected))
        let queries = await recorder.queries
        XCTAssertEqual(queries, ["Bonne Nouvelle"])
    }

    func testCanonicalGareNameIsSearchedBeforeRemovingItsQualifier() async throws {
        let expected = station("gare-de-lyon", "Gare de Lyon", modes: [.rer])
        let recorder = PlaceResolverQueryRecorder(result: expected)
        let resolver = OnDevicePlaceResolver { query, _ in
            await recorder.response(for: query)
        }

        let resolution = try await resolver.resolve("Gare de Lyon", near: nil)

        XCTAssertEqual(resolution, .resolved(expected))
        let queries = await recorder.queries
        XCTAssertEqual(queries, ["Gare de Lyon"])
    }

    func testComposedTransitQualifiersAreRemovedAsOneSemanticPrefix() async throws {
        let cases: [(input: String, canonicalName: String, mode: TransitMode)] = [
            ("station RER Auber", "Auber", .rer),
            ("station de tram Porte de Versailles", "Porte de Versailles", .tram),
            ("arrêt de bus République", "République", .bus),
            ("métro Bonne Nouvelle", "Bonne Nouvelle", .metro),
        ]

        for (index, testCase) in cases.enumerated() {
            let expected = station(
                "qualified-station-\(index)",
                testCase.canonicalName,
                modes: [testCase.mode]
            )
            let recorder = PlaceResolverQueryRecorder(result: expected)
            let resolver = OnDevicePlaceResolver { query, _ in
                await recorder.response(for: query)
            }

            let resolution = try await resolver.resolve(testCase.input, near: nil)

            XCTAssertEqual(resolution, .resolved(expected), testCase.input)
            let queries = await recorder.queries
            XCTAssertEqual(queries, [testCase.canonicalName], testCase.input)
        }
    }

    func testExplicitTransitRequestNeverFallsBackToAnAddress() async throws {
        let resolver = resolver(results: [
            address("bonne-nouvelle-address", "Bonne Nouvelle"),
        ])

        let resolution = try await resolver.resolve("station Bonne Nouvelle", near: nil)

        XCTAssertEqual(resolution, .notFound)
    }

    func testTransitHintFromGroundedEvidenceAlsoClosesTheCatalog() async throws {
        let resolver = resolver(results: [
            address("auber-address", "Auber"),
        ])

        let resolution = try await resolver.resolve(
            "Auber",
            hint: .transit,
            near: nil
        )

        XCTAssertEqual(resolution, .notFound)
    }

    func testExplicitAddressRequestNeverFallsBackToAStation() async throws {
        let resolver = resolver(results: [
            station("republique", "République", modes: [.metro]),
        ])

        let resolution = try await resolver.resolve("adresse de République", near: nil)

        XCTAssertEqual(resolution, .notFound)
    }

    func testAddressHintFromGroundedEvidenceAlsoClosesTheCatalog() async throws {
        let resolver = resolver(results: [
            station("republique", "République", modes: [.metro]),
        ])

        let resolution = try await resolver.resolve(
            "République",
            hint: .address,
            near: nil
        )

        XCTAssertEqual(resolution, .notFound)
    }

    func testExactTransitNameWinsOverAnAddressShapedName() async throws {
        let expected = station("place-italie", "Place d’Italie", modes: [.metro])
        let resolver = resolver(results: [
            address("place-italie-address", "Place d’Italie"),
            expected,
        ])

        let resolution = try await resolver.resolve("Place d’Italie", near: nil)

        XCTAssertEqual(resolution, .resolved(expected))
    }

    func testExplicitCityCenterWordingSelectsTheMunicipalityCandidate() async throws {
        let expected = address("chatou-municipality", "Chatou")
        let recorder = PlaceResolverQueryRecorder(result: expected)
        let resolver = OnDevicePlaceResolver { query, _ in
            await recorder.response(for: query)
        }

        let resolution = try await resolver.resolve("centre-ville de Chatou", near: nil)

        XCTAssertEqual(resolution, .resolved(expected))
        let queries = await recorder.queries
        XCTAssertEqual(queries, ["Chatou"])
    }

    func testGareSaintLazareDoesNotResolveToRueSaintLazare() async throws {
        let expected = station("saint-lazare", "Gare Saint-Lazare")
        let resolver = resolver(results: [
            address("rue-saint-lazare", "Rue Saint-Lazare"),
            expected,
        ])

        let resolution = try await resolver.resolve("gare saint lazare", near: nil)

        XCTAssertEqual(resolution, .resolved(expected))
    }

    func testSeveralRelevantCandidatesAreAmbiguousAndCappedAtFive() async throws {
        let candidates = (1...7).map { station("gare-\($0)", "Gare \($0)") }
        let resolver = resolver(results: candidates)

        let resolution = try await resolver.resolve("gare", near: nil)

        XCTAssertEqual(resolution, .ambiguous(Array(candidates.prefix(5))))
    }

    func testUniqueCloseMunicipalityResolvesAOneCharacterTypo() async throws {
        let expected = address("saint-germain", "Saint-Germain-en-Laye")
        let resolver = resolver(results: [
            expected,
            address("saint-leger", "Rue Saint Léger"),
            address("pontel", "Rue du Pontel"),
        ])

        let resolution = try await resolver.resolve("saint germain en lay", near: nil)

        XCTAssertEqual(resolution, .resolved(expected))
    }

    func testTwoEquallyCloseCandidatesRemainAmbiguous() async throws {
        let candidates = [
            station("gare-du-nord", "Gare du Nord"),
            station("gare-du-nors", "Gare du Nors"),
        ]
        let resolver = resolver(results: candidates)

        let resolution = try await resolver.resolve("Gare du Nor", near: nil)

        XCTAssertEqual(resolution, .ambiguous(candidates))
    }

    func testExplicitAddressUsesTheUniqueAddressCandidate() async throws {
        let expected = address("rivoli", "12 rue de Rivoli")
        let resolver = resolver(results: [station("rivoli", "Rivoli"), expected])

        let resolution = try await resolver.resolve("12 rue de Rivoli", near: nil)

        XCTAssertEqual(resolution, .resolved(expected))
    }

    func testUnavailableAddressSourceIsNotReportedAsNoResult() async throws {
        let resolver = OnDevicePlaceResolver { _, _ in
            SearchResponse(results: [], addressSource: .unavailable)
        }

        let resolution = try await resolver.resolve("12 rue inconnue", near: nil)

        XCTAssertEqual(resolution, .unavailable)
    }

    private func resolver(results: [SearchResult]) -> OnDevicePlaceResolver {
        OnDevicePlaceResolver { _, _ in
            SearchResponse(results: results, addressSource: .ok)
        }
    }

    private func station(
        _ id: String,
        _ name: String,
        modes: [TransitMode] = [],
    ) -> SearchResult {
        .station(StationSearchResult(
            id: StationID(rawValue: id),
            name: name,
            coordinate: .init(latitude: 48.85, longitude: 2.35),
            routes: modes.enumerated().map { index, mode in
                RouteBadge(
                    id: RouteID(rawValue: "\(id)-\(index)"),
                    shortName: "\(index)",
                    mode: mode,
                    colorHex: "#000000",
                    textColorHex: "#FFFFFF"
                )
            },
            distanceMeters: nil
        ))
    }

    private func address(_ id: String, _ name: String) -> SearchResult {
        .address(AddressSearchResult(
            id: id,
            name: name,
            context: "Paris",
            coordinate: .init(latitude: 48.86, longitude: 2.34),
            distanceMeters: nil
        ))
    }
}

private actor PlaceResolverQueryRecorder {
    private(set) var queries: [String] = []
    let result: SearchResult

    init(result: SearchResult) {
        self.result = result
    }

    func response(for query: String) -> SearchResponse {
        queries.append(query)
        return SearchResponse(results: [result], addressSource: .ok)
    }
}
