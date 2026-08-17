import XCTest
@testable import Via

final class OnDevicePlaceResolverTests: XCTestCase {
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

    func testSeveralRelevantCandidatesAreAmbiguousAndCappedAtFive() async throws {
        let candidates = (1...7).map { station("gare-\($0)", "Gare \($0)") }
        let resolver = resolver(results: candidates)

        let resolution = try await resolver.resolve("gare", near: nil)

        XCTAssertEqual(resolution, .ambiguous(Array(candidates.prefix(5))))
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

    private func station(_ id: String, _ name: String) -> SearchResult {
        .station(StationSearchResult(
            id: StationID(rawValue: id),
            name: name,
            coordinate: .init(latitude: 48.85, longitude: 2.35),
            routes: [],
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
