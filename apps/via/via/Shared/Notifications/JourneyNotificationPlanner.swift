import Foundation

struct JourneyNotificationPreferences: Codable, Sendable, Hashable {
    enum DepartureLeadTime: Int, CaseIterable, Codable, Sendable, Hashable, Identifiable {
        case fiveMinutes = 5
        case tenMinutes = 10
        case fifteenMinutes = 15
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

    var requestIdentifier: String { "via.journey.\(journeyID.rawValue).\(id)" }

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
    let scheduledAt: Date
    let events: [JourneyNotificationEvent]

    var id: JourneyID { journey.id }
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
