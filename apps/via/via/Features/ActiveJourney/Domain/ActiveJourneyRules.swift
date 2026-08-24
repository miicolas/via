import Foundation

enum JourneyActivationAction: String, Sendable, Equatable {
    case go
    case plan
    case planned
    case resume
    case active

    var title: String {
        switch self {
        case .go: "Go"
        case .plan: "Prévoir"
        case .planned: "Trajet prévu"
        case .resume: "Reprendre"
        case .active: "Trajet actif"
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
    /// A point older than this is no longer trusted as a live position. The
    /// projector can still use the cached journey and timetable in its place.
    static let locationFreshnessInterval: TimeInterval = 30
    static let missedConnectionGracePeriod: TimeInterval = 2 * 60
    static let restorationGracePeriod: TimeInterval = 30 * 60

    static func activationAction(
        for journey: Journey,
        now: Date
    ) -> JourneyActivationAction {
        return journey.departureAt.timeIntervalSince(now) <= imminentDepartureInterval
            ? .go
            : .plan
    }

    /// Resolves the detail screen's context without letting a planned origin
    /// accidentally start live guidance. An existing active session always
    /// wins; opening the saved draft explicitly turns it back into Go.
    static func detailAction(
        activeAction: JourneyActivationAction,
        isPlanned: Bool,
        prefersGo: Bool,
        prefersPlan: Bool
    ) -> JourneyActivationAction {
        if activeAction == .active || activeAction == .resume {
            return activeAction
        }
        if prefersGo { return .go }
        if isPlanned { return .planned }
        if prefersPlan { return .plan }
        return activeAction
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
        sectionIndex(in: schedule(for: journey), at: now)
    }

    /// For callers that already hold the schedule — building it a second time
    /// walks every section of the journey for nothing.
    static func sectionIndex(in sections: [JourneySectionSchedule], at now: Date) -> Int {
        guard !sections.isEmpty else { return 0 }
        if now < sections[0].startsAt { return 0 }
        return sections.lastIndex(where: { now >= $0.startsAt }) ?? 0
    }

    /// The sections whose departure the traveller may still re-pick.
    ///
    /// One rule, because three surfaces asked the same question and answered it
    /// differently: the planning screen ("is it in the future?"), the guidance
    /// panel ("…and not behind the cursor, and not the leg I am riding"), and
    /// the server, which decides which sections get choices at all. The
    /// planning screen simply has no `progress`, which is why the same function
    /// serves both.
    ///
    /// Riding a leg is the interesting case: swapping the train you are already
    /// on is not a choice the traveller can act on, so it is offered only while
    /// tracking says they are not yet aboard.
    static func revisableSectionIDs(
        in journey: Journey,
        progress: JourneyProgress?,
        isTracking: Bool,
        at now: Date
    ) -> Set<String> {
        var revisable: Set<String> = []
        for (index, section) in journey.sections.enumerated() {
            guard let departureAt = section.departureAt, departureAt > now else { continue }
            if let progress {
                guard index >= progress.sectionIndex else { continue }
                if isTracking, index == progress.sectionIndex, section.kind == .transit {
                    continue
                }
            }
            revisable.insert(section.id)
        }
        return revisable
    }

    static func nextMonitoringDelay(in journey: Journey, at now: Date) -> TimeInterval {
        let schedule = schedule(for: journey)
        let closeToTransition = schedule.contains { section in
            abs(section.startsAt.timeIntervalSince(now)) <= transitionWindow ||
                abs(section.endsAt.timeIntervalSince(now)) <= transitionWindow
        }
        let cadence = closeToTransition
            ? transitionMonitoringInterval
            : standardMonitoringInterval
        let expiration = journey.arrivalAt.addingTimeInterval(restorationGracePeriod)
        let nextTransition = (schedule
            .flatMap { [$0.startsAt, $0.endsAt] } + [expiration])
            .map { $0.timeIntervalSince(now) }
            .filter { $0 > 0 }
            .min()
        return min(cadence, nextTransition ?? cadence)
    }

    static func isExpired(_ journey: Journey, at now: Date) -> Bool {
        now >= journey.arrivalAt.addingTimeInterval(restorationGracePeriod)
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
              now >= schedule.startsAt.addingTimeInterval(missedConnectionGracePeriod) else {
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
