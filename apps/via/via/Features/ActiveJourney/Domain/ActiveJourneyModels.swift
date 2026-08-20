import Foundation

struct ActiveJourneySession: Codable, Sendable, Hashable, Identifiable {
    let journey: Journey
    let destination: JourneyDestination
    let source: JourneyResult.Source?
    var requiresAccessibleStations = false
    var currentSectionIndex: Int
    var lastCoordinate: GeoCoordinate?
    var horizontalAccuracy: Double?
    var manualOverrideUntil: Date?
    var isTrackingStarted: Bool
    var allowsBackgroundTracking: Bool

    var id: JourneyID { journey.id }

    var currentSection: JourneySection? {
        guard journey.sections.indices.contains(currentSectionIndex) else { return nil }
        return journey.sections[currentSectionIndex]
    }

    private enum CodingKeys: String, CodingKey {
        case journey
        case destination
        case source
        case requiresAccessibleStations
        case currentSectionIndex
        case lastCoordinate
        case horizontalAccuracy
        case manualOverrideUntil
        case isTrackingStarted
        case allowsBackgroundTracking
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        journey = try container.decode(Journey.self, forKey: .journey)
        destination = try container.decode(JourneyDestination.self, forKey: .destination)
        source = try container.decodeIfPresent(JourneyResult.Source.self, forKey: .source)
        requiresAccessibleStations = try container.decodeIfPresent(Bool.self, forKey: .requiresAccessibleStations) ?? false
        currentSectionIndex = try container.decode(Int.self, forKey: .currentSectionIndex)
        lastCoordinate = try container.decodeIfPresent(GeoCoordinate.self, forKey: .lastCoordinate)
        horizontalAccuracy = try container.decodeIfPresent(Double.self, forKey: .horizontalAccuracy)
        manualOverrideUntil = try container.decodeIfPresent(Date.self, forKey: .manualOverrideUntil)
        isTrackingStarted = try container.decode(Bool.self, forKey: .isTrackingStarted)
        allowsBackgroundTracking = try container.decode(Bool.self, forKey: .allowsBackgroundTracking)
    }
}

struct ActiveJourneyAlternative: Sendable, Hashable, Identifiable {
    let journey: Journey
    let otherJourneys: [Journey]
    let source: JourneyResult.Source?
    let currentArrivalAt: Date

    init?(journeys: [Journey], source: JourneyResult.Source?, currentArrivalAt: Date) {
        let sortedJourneys = journeys.sorted { $0.arrivalAt < $1.arrivalAt }
        guard let journey = sortedJourneys.first else { return nil }
        self.journey = journey
        otherJourneys = Array(sortedJourneys.dropFirst())
        self.source = source
        self.currentArrivalAt = currentArrivalAt
    }

    var id: JourneyID { journey.id }
    var journeys: [Journey] { [journey] + otherJourneys }
    var minutesSaved: Int {
        max(0, Int(ceil(currentArrivalAt.timeIntervalSince(journey.arrivalAt) / 60)))
    }
}

struct JourneyArrival: Sendable, Hashable, Identifiable {
    let journeyID: JourneyID
    let destinationName: String
    let arrivedAt: Date

    var id: JourneyID { journeyID }
}

enum ActiveJourneyPhase: Sendable, Equatable {
    case scheduled(TimeInterval)
    case underway
}

enum ActiveJourneyRecalculationState: Sendable, Equatable {
    case idle
    case checking
    case offline
    case noRoute
    case failed(ViaError)
}

struct ActiveJourneyInstruction: Sendable, Hashable {
    let title: String
    let detail: String?
    let route: JourneyRoute?
    let startsAt: Date?
    let endsAt: Date?
    let stops: [JourneyStop]
    let sectionKind: JourneySection.Kind
}
