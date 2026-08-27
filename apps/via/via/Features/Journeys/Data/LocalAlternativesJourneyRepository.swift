import Foundation

struct LocalAlternativesJourneyRepository: JourneyRepository, Sendable {
    private let base: any JourneyRepository
    private let direct: any DirectJourneyRouter

    init(base: any JourneyRepository, direct: any DirectJourneyRouter) {
        self.base = base
        self.direct = direct
    }

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        async let localRoutes = direct.routes(for: request)

        do {
            let result = try await base.plan(request)
            return Self.merge(await localRoutes, into: result)
        } catch {
            let routes = await localRoutes
            guard !routes.isEmpty else { throw error }
            // A walk and a ride are what is left when the planner does not
            // answer, not a plan that succeeded: the result stays unavailable
            // so the screen says the transit itineraries are missing.
            return JourneyResult(
                status: .unavailable,
                source: .theoretical,
                generatedAt: .now,
                journeys: Self.directJourneys(routes),
                reason: .transitUnavailable
            )
        }
    }

    static func merge(_ local: [Journey], into result: JourneyResult) -> JourneyResult {
        guard !local.isEmpty || result.journeys.contains(where: isDirectJourney) else {
            return result
        }

        let transit = result.journeys.filter { !isDirectJourney($0) }
        let journeys = transit + directJourneys(local + result.journeys.filter(isDirectJourney))
        guard !journeys.isEmpty else { return result }

        // Walking and cycling ride alongside the transit answer; they never
        // stand in for one. With no transit journey left, the base status and
        // its reason survive untouched — a plan that found nothing, or a
        // filter that ruled everything out, still reads that way on screen.
        return JourneyResult(
            status: transit.isEmpty ? result.status : .ready,
            source: result.source ?? .theoretical,
            generatedAt: result.generatedAt,
            journeys: journeys,
            reason: transit.isEmpty ? result.reason : nil
        )
    }

    /// The first route offered for a mode wins — a local alternative comes
    /// before the server's own direct path, which is what makes the fallback a
    /// preference rather than a duplicate.
    private static func directJourneys(_ journeys: [Journey]) -> [Journey] {
        var byMode: [Journey.Qualifier: Journey] = [:]
        for journey in journeys {
            guard let mode = directMode(of: journey), byMode[mode] == nil else {
                continue
            }
            byMode[mode] = journey
        }
        return [.walking, .bike].compactMap { byMode[$0] }
    }

    private static func isDirectJourney(_ journey: Journey) -> Bool {
        JourneyShape.of(journey).isDirectPath
    }

    private static func directMode(of journey: Journey) -> Journey.Qualifier? {
        switch JourneyShape.of(journey) {
        case .walking: .walking
        case .cycling, .walkingAndCycling: .bike
        case .transit: nil
        }
    }
}
