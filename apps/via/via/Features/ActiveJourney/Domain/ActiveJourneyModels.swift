import Foundation

struct ActiveJourneySession: Codable, Sendable, Hashable, Identifiable {
    var journey: Journey
    let destination: JourneyDestination
    let source: JourneyResult.Source?
    var planningPolicy: JourneyPlanningPolicy
    var currentSectionIndex: Int
    var lastCoordinate: GeoCoordinate?
    var horizontalAccuracy: Double?
    /// The timestamp of the most recent native location sample. A restored
    /// journey keeps its last confirmed section but never advances without a
    /// fresh sample.
    var lastLocationAt: Date?
    var isTrackingStarted: Bool
    var allowsBackgroundTracking: Bool

    var id: JourneyID { journey.id }

    /// Reads through to the policy the session was planned with. Stored
    /// separately it was a second copy the initialiser happily let disagree.
    var requiresAccessibleStations: Bool { planningPolicy.requiresAccessibleStations }

    var currentSection: JourneySection? {
        guard journey.sections.indices.contains(currentSectionIndex) else { return nil }
        return journey.sections[currentSectionIndex]
    }

    init(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy,
        currentSectionIndex: Int,
        lastCoordinate: GeoCoordinate?,
        horizontalAccuracy: Double?,
        lastLocationAt: Date? = nil,
        isTrackingStarted: Bool,
        allowsBackgroundTracking: Bool
    ) {
        self.journey = journey
        self.destination = destination
        self.source = source
        self.planningPolicy = planningPolicy
        self.currentSectionIndex = currentSectionIndex
        self.lastCoordinate = lastCoordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.lastLocationAt = lastLocationAt
        self.isTrackingStarted = isTrackingStarted
        self.allowsBackgroundTracking = allowsBackgroundTracking
    }

    private enum CodingKeys: String, CodingKey {
        case journey
        case destination
        case source
        case planningPolicy
        case currentSectionIndex
        case lastCoordinate
        case horizontalAccuracy
        case lastLocationAt
        case isTrackingStarted
        case allowsBackgroundTracking
    }

    /// The pre-policy shape: a bare accessibility flag and nothing else.
    private enum LegacyCodingKeys: String, CodingKey {
        case requiresAccessibleStations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        journey = try container.decode(Journey.self, forKey: .journey)
        destination = try container.decode(JourneyDestination.self, forKey: .destination)
        source = try container.decodeIfPresent(JourneyResult.Source.self, forKey: .source)
        // Sessions written before the policy existed carry only the flag.
        planningPolicy = try container.decodeIfPresent(
            JourneyPlanningPolicy.self,
            forKey: .planningPolicy
        ) ?? JourneyPlanningPolicy(
            requiresAccessibleStations: try decoder
                .container(keyedBy: LegacyCodingKeys.self)
                .decodeIfPresent(Bool.self, forKey: .requiresAccessibleStations) ?? false
        )
        currentSectionIndex = try container.decode(Int.self, forKey: .currentSectionIndex)
        lastCoordinate = try container.decodeIfPresent(GeoCoordinate.self, forKey: .lastCoordinate)
        horizontalAccuracy = try container.decodeIfPresent(Double.self, forKey: .horizontalAccuracy)
        lastLocationAt = try container.decodeIfPresent(Date.self, forKey: .lastLocationAt)
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
