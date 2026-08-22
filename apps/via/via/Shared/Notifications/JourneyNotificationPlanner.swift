import Foundation

struct JourneyNotificationPreferences: Codable, Sendable, Hashable {
    enum DepartureLeadTime: Int, CaseIterable, Codable, Sendable, Hashable, Identifiable {
        case fiveMinutes = 5
        case tenMinutes = 10
        case fifteenMinutes = 15
        case twentyMinutes = 20
        case twentyFiveMinutes = 25
        case thirtyMinutes = 30

        var id: Int { rawValue }
        var seconds: TimeInterval { TimeInterval(rawValue * 60) }
        var title: String { "\(rawValue) minutes" }
    }

    var departureLeadTime: DepartureLeadTime = .tenMinutes
}

struct JourneyNotificationEvent: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable, Hashable {
        case departure
        case connection
        case arrival
    }

    let journeyID: JourneyID
    let kind: Kind
    let identifier: String
    let date: Date
    let title: String
    let body: String

    var id: String { identifier }

    /// The orphan sweep matches on this prefix, so the scheme lives here rather
    /// than as a literal in the coordinator that would not fail to compile.
    static let requestIdentifierPrefix = "via.journey."

    var requestIdentifier: String {
        "\(Self.requestIdentifierPrefix)\(journeyID.rawValue).\(id)"
    }

    var deepLink: URL {
        var components = URLComponents()
        components.scheme = "via"
        components.host = "journey"
        components.queryItems = [
            URLQueryItem(name: "journeyId", value: journeyID.rawValue),
            URLQueryItem(name: "mode", value: "reminder"),
        ]
        return components.url ?? URL(string: "via://journey")!
    }

    var userInfo: [String: String] {
        [
            "type": "journey",
            "event": kind.rawValue,
            "journeyId": journeyID.rawValue,
            "url": deepLink.absoluteString,
            "deepLink": deepLink.absoluteString,
        ]
    }
}

struct ScheduledJourneyReminder: Codable, Sendable, Hashable, Identifiable {
    let journey: Journey
    let destination: JourneyDestination
    let source: JourneyResult.Source?
    let planningPolicy: JourneyPlanningPolicy
    let scheduledAt: Date
    let events: [JourneyNotificationEvent]

    var id: JourneyID { journey.id }

    init(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy = JourneyPlanningPolicy(),
        scheduledAt: Date,
        events: [JourneyNotificationEvent]
    ) {
        self.journey = journey
        self.destination = destination
        self.source = source
        self.planningPolicy = planningPolicy
        self.scheduledAt = scheduledAt
        self.events = events
    }

    private enum CodingKeys: String, CodingKey {
        case journey, destination, source, planningPolicy, scheduledAt, events
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        journey = try container.decode(Journey.self, forKey: .journey)
        destination = try container.decode(JourneyDestination.self, forKey: .destination)
        source = try container.decodeIfPresent(JourneyResult.Source.self, forKey: .source)
        planningPolicy = try container.decodeIfPresent(
            JourneyPlanningPolicy.self,
            forKey: .planningPolicy
        ) ?? JourneyPlanningPolicy(requiresAccessibleStations: journey.accessibility != nil)
        scheduledAt = try container.decode(Date.self, forKey: .scheduledAt)
        events = try container.decode([JourneyNotificationEvent].self, forKey: .events)
    }
}

enum JourneyNotificationPlanner {
    /// Computes a stable, timetable-based notification plan. The planner does
    /// not touch UserNotifications, which keeps DST, filtering and duplicate
    /// behavior straightforward to test.
    static func events(
        for journey: Journey,
        preferences: JourneyNotificationPreferences,
        now: Date,
        destinationName: String? = nil
    ) -> [JourneyNotificationEvent] {
        var candidates: [JourneyNotificationEvent] = [
            JourneyNotificationEvent(
                journeyID: journey.id,
                kind: .departure,
                identifier: "departure",
                date: journey.departureAt.addingTimeInterval(-preferences.departureLeadTime.seconds),
                title: "Départ dans \(preferences.departureLeadTime.rawValue) minutes",
                body: "Votre trajet vers \(destinationName ?? journeyDestinationName(for: journey)) commence bientôt."
            )
        ]

        let schedules = ActiveJourneyRules.schedule(for: journey)
        let transitSchedules = schedules.filter { $0.section.kind == .transit }

        for schedule in transitSchedules.dropFirst() {
            let routeName = schedule.section.route?.shortName ?? "la prochaine ligne"
            candidates.append(
                JourneyNotificationEvent(
                    journeyID: journey.id,
                    kind: .connection,
                    identifier: "connection-\(schedule.section.id)",
                    date: schedule.startsAt,
                    title: "Correspondance · \(routeName)",
                    body: "Votre correspondance part de \(schedule.section.from.name)."
                )
            )
        }

        candidates.append(
            JourneyNotificationEvent(
                journeyID: journey.id,
                kind: .arrival,
                identifier: "arrival",
                date: journey.arrivalAt,
                title: "Arrivée prévue",
                body: "Votre trajet arrive bientôt à destination."
            )
        )

        var seen = Set<String>()
        return candidates
            .sorted { lhs, rhs in
                if lhs.date == rhs.date { return lhs.kind.rawValue < rhs.kind.rawValue }
                return lhs.date < rhs.date
            }
            .filter { event in
                guard event.date > now else { return false }
                let key = "\(event.kind.rawValue)|\(event.date.timeIntervalSince1970)"
                return seen.insert(key).inserted
            }
    }

    private static func journeyDestinationName(for journey: Journey) -> String {
        journey.sections.last?.to.name ?? "destination"
    }
}
