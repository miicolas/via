import Foundation
import Testing
@testable import Via

struct ChatStreamParserTests {
    @Test
    func parsesEventsWhenUtf8BytesArriveOneAtATime() throws {
        let encoded = try JSONEncoder().encode(ChatStreamEvent.textDelta("Métro à Châtelet")) + Data([0x0A])
        var parser = ChatStreamParser()
        var events: [ChatStreamEvent] = []

        for byte in encoded {
            events += try parser.append(Data([byte]))
        }

        #expect(events.count == 1)
        #expect(events.first?.equalsText("Métro à Châtelet") == true)
    }

    @Test
    func keepsAnUnterminatedEventUntilTheStreamFinishes() throws {
        let encoded = try JSONEncoder().encode(ChatStreamEvent.finished)
        var parser = ChatStreamParser()

        #expect(try parser.append(encoded).isEmpty)
        #expect(try parser.finish().count == 1)
    }

    @Test
    func decodesTheNativeItineraryDestinationShape() throws {
        let destination = JourneyDestination(
            kind: .station,
            id: "station-chatelet",
            name: "Châtelet",
            context: "Paris",
            coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3470)
        )
        let response = JourneysResponse(
            status: .ready,
            source: nil,
            generatedAt: "2026-08-15T10:00:00.000Z",
            journeys: []
        )
        let encoded = try JSONEncoder().encode(
            ChatStreamEvent.itinerary(destination: destination, response: response)
        ) + Data([0x0A])
        var parser = ChatStreamParser()

        guard case .itinerary(let decodedDestination, let decodedResponse) = try parser.append(encoded).first else {
            Issue.record("Expected a native itinerary event")
            return
        }
        #expect(decodedDestination == destination)
        #expect(decodedResponse == response)
    }
}

private extension ChatStreamEvent {
    func equalsText(_ expected: String) -> Bool {
        guard case .textDelta(let text) = self else { return false }
        return text == expected
    }
}

@MainActor
struct ChatFeatureModelTests {
    @Test
    func cancellingAStreamReturnsTheModelToIdle() async throws {
        let model = ChatFeatureModel(
            client: BlockingChatClient(),
            locationProvider: DemoLocationProvider()
        )

        model.send("Comment aller à Châtelet ?")
        #expect(model.isStreaming)

        model.cancel()
        try await Task.sleep(for: .milliseconds(20))

        #expect(!model.isStreaming)
        #expect(model.status == .idle)
    }
}

private struct BlockingChatClient: ChatClient {
    func stream(
        messages: [ChatMessage],
        location: GeoCoordinate?,
        onEvent: @escaping @Sendable (ChatStreamEvent) async -> Void
    ) async throws {
        try await Task.sleep(for: .seconds(60))
    }
}
