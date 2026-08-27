import Foundation

/// The on-device source of the routes the traveller covers on their own legs
/// or wheels — a walk, a ride — and nothing else.
///
/// Transit belongs to PRIM: the lines, the timetables and the realtime that
/// make an itinerary a transit itinerary only exist on the server, so a route
/// offered here can never be one. `LocalAlternativesJourneyRepository` enforces
/// it when it merges: a route of any other shape is dropped rather than
/// promoted into the list.
protocol DirectJourneyRouter: Sendable {
    func routes(for request: JourneyRequest) async -> [Journey]
}
