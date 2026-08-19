import Foundation

enum JourneyActivationAction: String, Sendable, Equatable {
    case go
    case activate
    case resume

    var title: String {
        switch self {
        case .go: "Go"
        case .activate: "Activer le trajet"
        case .resume: "Reprendre"
        }
    }
}

struct JourneySectionSchedule: Sendable, Hashable, Identifiable {
    let section: JourneySection
    let startsAt: Date
    let endsAt: Date

    var id: String { section.id }
}

enum ActiveJourneyRules {
    static let imminentDepartureInterval: TimeInterval = 10 * 60
    static let standardMonitoringInterval: TimeInterval = 2 * 60
    static let transitionMonitoringInterval: TimeInterval = 30
    static let transitionWindow: TimeInterval = 2 * 60
    static let missedConnectionGracePeriod: TimeInterval = 2 * 60
    static let restorationGracePeriod: TimeInterval = 30 * 60

    static func activationAction(
        for journey: Journey,
        activeJourneyID: JourneyID?,
        now: Date
    ) -> JourneyActivationAction {
        if activeJourneyID == journey.id { return .resume }
        return journey.departureAt.timeIntervalSince(now) <= imminentDepartureInterval
            ? .go
            : .activate
    }

    static func schedule(for journey: Journey) -> [JourneySectionSchedule] {
        var cursor = journey.departureAt

        return journey.sections.map { section in
            let startsAt = section.departureAt ?? cursor
            let durationEnd = startsAt.addingTimeInterval(TimeInterval(max(0, section.durationSeconds)))
            let endsAt = max(section.arrivalAt ?? durationEnd, startsAt)
            cursor = endsAt
            return JourneySectionSchedule(
                section: section,
                startsAt: startsAt,
                endsAt: endsAt
            )
        }
    }

    static func sectionIndex(in journey: Journey, at now: Date) -> Int {
        let sections = schedule(for: journey)
        guard !sections.isEmpty else { return 0 }
        if now < sections[0].startsAt { return 0 }
        return sections.lastIndex(where: { now >= $0.startsAt }) ?? 0
    }

    static func monitoringInterval(in journey: Journey, at now: Date) -> TimeInterval {
        let closeToTransition = schedule(for: journey).contains { section in
            abs(section.endsAt.timeIntervalSince(now)) <= transitionWindow
        }
        return closeToTransition ? transitionMonitoringInterval : standardMonitoringInterval
    }

    static func isExpired(_ journey: Journey, at now: Date) -> Bool {
        now > journey.arrivalAt.addingTimeInterval(restorationGracePeriod)
    }

    static func arrivalRadius(horizontalAccuracy: Double?) -> Double {
        guard let horizontalAccuracy, horizontalAccuracy.isFinite, horizontalAccuracy >= 0 else {
            return 150
        }
        return min(200, max(75, horizontalAccuracy * 2))
    }

    static func hasArrived(
        journey: Journey,
        coordinate: GeoCoordinate,
        horizontalAccuracy: Double?,
        now: Date
    ) -> Bool {
        guard let last = schedule(for: journey).last,
              now >= last.startsAt else { return false }
        return distance(from: coordinate, to: last.section.to.coordinate)
            <= arrivalRadius(horizontalAccuracy: horizontalAccuracy)
    }

    static func isConnectionCompromised(
        schedule: JourneySectionSchedule,
        coordinate: GeoCoordinate,
        now: Date
    ) -> Bool {
        guard schedule.section.kind == .transit,
              now > schedule.startsAt.addingTimeInterval(missedConnectionGracePeriod) else {
            return false
        }
        return distance(from: coordinate, to: schedule.section.from.coordinate) > 250
    }

    static func distance(from lhs: GeoCoordinate, to rhs: GeoCoordinate) -> Double {
        let earthRadius = 6_371_000.0
        let latitude1 = lhs.latitude * .pi / 180
        let latitude2 = rhs.latitude * .pi / 180
        let latitudeDelta = (rhs.latitude - lhs.latitude) * .pi / 180
        let longitudeDelta = (rhs.longitude - lhs.longitude) * .pi / 180
        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(latitude1) * cos(latitude2)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
