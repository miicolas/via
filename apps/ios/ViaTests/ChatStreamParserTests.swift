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
}

private extension ChatStreamEvent {
    func equalsText(_ expected: String) -> Bool {
        guard case .textDelta(let text) = self else { return false }
        return text == expected
    }
}
