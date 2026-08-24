protocol NetworkRepository: Sendable {
    func railMap() async throws -> TransitNetwork
    func viewport(in bounds: GeoBounds) async throws -> StationsArea
    /// Only called while the Vélib' layer is on, so the docks cost nothing to
    /// a map that is not showing them.
    func bikeStations(in bounds: GeoBounds) async throws -> BikeStationsArea
}
