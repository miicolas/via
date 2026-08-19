import XCTest
@testable import Via

final class LiveNetworkRepositoryTests: XCTestCase {
    /// One tile exactly: latitudes inside tile row 1954, longitudes inside column 94.
    private static let oneTileBounds = GeoBounds(
        minLatitude: 48.851,
        maxLatitude: 48.86,
        minLongitude: 2.351,
        maxLongitude: 2.36
    )

    func testConcurrentViewportsFetchEachTileOnce() async throws {
        let remote = NetworkRemoteSpy()
        let repository = LiveNetworkRepository(remote: remote)

        async let first = repository.viewport(in: Self.oneTileBounds)
        async let second = repository.viewport(in: Self.oneTileBounds)
        _ = try await (first, second)

        let visibleTile = ViewportTile.covering(Self.oneTileBounds).first!
        let calls = await remote.callCount(for: visibleTile.bounds)
        XCTAssertEqual(calls, 1)
    }

    func testViewportPrefetchesTheNeighbouringRing() async throws {
        let remote = NetworkRemoteSpy()
        let repository = LiveNetworkRepository(remote: remote)

        _ = try await repository.viewport(in: Self.oneTileBounds)

        let visibleTile = ViewportTile.covering(Self.oneTileBounds).first!
        var expected: Set<String> = []
        for latitudeOffset in -1...1 {
            for longitudeOffset in -1...1 {
                expected.insert(ViewportTile(
                    latitudeIndex: visibleTile.latitudeIndex + latitudeOffset,
                    longitudeIndex: visibleTile.longitudeIndex + longitudeOffset
                ).id)
            }
        }
        await waitUntil { await remote.requestedTileIDs() == expected }
    }

    func testFailedTileIsNotRetriedDuringTheCooldown() async throws {
        let remote = NetworkRemoteSpy()
        await remote.setFailing(true)
        let repository = LiveNetworkRepository(remote: remote)

        _ = try await repository.viewport(in: Self.oneTileBounds)
        // Let the prefetch of the ring fail too, so the second pass is quiet.
        await waitUntil { await remote.totalCalls() == 9 }

        _ = try await repository.viewport(in: Self.oneTileBounds)
        try await Task.sleep(for: .milliseconds(20))

        let total = await remote.totalCalls()
        XCTAssertEqual(total, 9)
    }

    func testFailedTileIsRetriedOnceTheCooldownExpires() async throws {
        let remote = NetworkRemoteSpy()
        await remote.setFailing(true)
        let repository = LiveNetworkRepository(remote: remote, retryCooldown: .milliseconds(1))

        _ = try await repository.viewport(in: Self.oneTileBounds)
        await waitUntil { await remote.totalCalls() == 9 }
        try await Task.sleep(for: .milliseconds(10))

        await remote.setFailing(false)
        let area = try await repository.viewport(in: Self.oneTileBounds)

        let visibleTile = ViewportTile.covering(Self.oneTileBounds).first!
        let calls = await remote.callCount(for: visibleTile.bounds)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(area.stations.map(\.id), [StationID(rawValue: "station")])
    }

    private func waitUntil(
        _ predicate: @escaping () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<200 {
            if await predicate() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Condition was not met", file: file, line: line)
    }
}

private actor NetworkRemoteSpy: NetworkRemote {
    private var tileCalls: [GeoBounds] = []
    private var failing = false

    func railMap() -> TransitNetwork {
        TransitNetwork(routes: [], stations: [])
    }

    func stationsTile(in bounds: GeoBounds) async throws -> StationsArea {
        tileCalls.append(bounds)
        if failing { throw ViaError.transport }
        return StationsArea(
            stations: [NetworkStation(
                id: StationID(rawValue: "station"),
                name: "station",
                coordinate: GeoCoordinate(
                    latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
                    longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
                ),
                routeIDs: []
            )],
            routes: []
        )
    }

    func setFailing(_ value: Bool) {
        failing = value
    }

    func totalCalls() -> Int {
        tileCalls.count
    }

    func callCount(for bounds: GeoBounds) -> Int {
        tileCalls.count { $0 == bounds }
    }

    func requestedTileIDs() -> Set<String> {
        // A tile's own bounds sit exactly on the grid, so identify it from the
        // min corner rather than `covering`, which would span two rows.
        Set(tileCalls.map { bounds in
            ViewportTile(
                latitudeIndex: Int((bounds.minLatitude / ViewportTile.sizeInDegrees).rounded()),
                longitudeIndex: Int((bounds.minLongitude / ViewportTile.sizeInDegrees).rounded())
            ).id
        })
    }
}
