import Foundation

struct JourneySegment: Hashable, Identifiable, Sendable {
    let id: String
    let kind: Kind
    let minutes: Int
    let route: JourneyRoute?

    enum Kind: Hashable, Sendable {
        case transit
        case walk
        case wait
    }
}

func journeySegments(_ journey: Journey) -> [JourneySegment] {
    var segments: [JourneySegment] = []

    for (index, section) in journey.sections.enumerated() {
        let kind: JourneySegment.Kind
        switch section.type {
        case .transit where section.route != nil:
            kind = .transit
        case .wait, .transit:
            kind = .wait
        case .walk, .transfer:
            kind = .walk
        }

        if let previous = segments.last, previous.kind == kind, kind != .transit {
            segments[segments.count - 1] = JourneySegment(
                id: previous.id,
                kind: previous.kind,
                minutes: previous.minutes + max(1, Int((Double(section.durationSeconds) / 60).rounded())),
                route: previous.route
            )
            continue
        }

        segments.append(
            JourneySegment(
                id: "\(kind):\(section.from.name):\(section.to.name):\(index)",
                kind: kind,
                minutes: max(1, Int((Double(section.durationSeconds) / 60).rounded())),
                route: section.route
            )
        )
    }

    return segments
}

func journeyMinutes(_ seconds: Int) -> Int {
    max(1, Int((Double(seconds) / 60).rounded()))
}

func journeyDepartureDate(_ journey: Journey) -> Date? {
    journey.departureAt.iso8601Date
}

func journeyTimeLabel(_ timestamp: String?) -> String? {
    guard let timestamp, let date = timestamp.iso8601Date else { return nil }
    return date.formatted(.dateTime.hour().minute())
}
