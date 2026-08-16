protocol NetworkRepository: Sendable {
    func railMap() async throws -> TransitNetwork
    func viewport(in bounds: GeoBounds) async throws -> StationsArea
}
