protocol NetworkRepository: Sendable {
    func railMap() async throws -> TransitNetwork
    func viewport(in bounds: GeoBounds) async throws -> StationsArea
    /// Only called while the Vélib' layer is on, so the docks cost nothing to
    /// a map that is not showing them.
    func bikeStations(in bounds: GeoBounds) async throws -> BikeStationsArea
    /// The normalized multi-provider map layer. A default keeps non-map
    /// repositories focused on transit while the feature is opt-in.
    func sharedMobility(in bounds: GeoBounds) async throws -> SharedMobilityArea
}

extension NetworkRepository {
    func sharedMobility(in bounds: GeoBounds) async throws -> SharedMobilityArea {
        SharedMobilityArea()
    }

    /// The Vélib'-only seam, kept for previews and repository implementations
    /// that predate the generic layer.
    ///
    /// The condition is written once here rather than at each load and refresh
    /// path: a live response always carries all four source statuses, so this
    /// answers empty for the real API, and no caller can forget to clear the
    /// docks when the generic layer did answer.
    func legacyBikeStations(
        in bounds: GeoBounds,
        whenGenericSourcesAre sources: [SharedMobilityProvider: SharedMobilitySourceStatus],
        wanted: Bool
    ) async throws -> BikeStationsArea {
        guard wanted, sources.isEmpty else { return BikeStationsArea() }
        return try await bikeStations(in: bounds)
    }
}
