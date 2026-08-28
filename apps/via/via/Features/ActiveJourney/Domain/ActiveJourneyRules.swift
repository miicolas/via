import Foundation

enum JourneyActivationAction: String, Sendable, Equatable {
    case go
    case plan
    case planned
    case resume
    case active

    var title: String {
        switch self {
        case .go: "GO"
        case .plan: "Prévoir"
        case .planned: "Trajet prévu"
        case .resume: "Reprendre"
        case .active: "Trajet actif"
        }
    }

    static let goTitleVariants = [
        "GO",
        "En route",
        "C’est parti",
        "On y va",
        "Lancer",
        "Démarrer",
    ]

    /// Picked once per launch: two surfaces can show the Go action at the same
    /// time, and they must show the same verb.
    static let launchGoTitle = goTitleVariants.randomElement() ?? "GO"

    var displayTitle: String {
        self == .go ? Self.launchGoTitle : title
    }
}

struct JourneySectionSchedule: Sendable, Hashable, Identifiable {
    let section: JourneySection
    /// The line actually followed on this section — see `Journey.path(at:)`.
    let path: [GeoCoordinate]
    let startsAt: Date
    let endsAt: Date

    var id: String { section.id }
}

enum ActiveJourneyRules {
    static let imminentDepartureInterval: TimeInterval = 10 * 60
    static let futureJourneyRequestTolerance: TimeInterval = 60
    static let standardMonitoringInterval: TimeInterval = 2 * 60
    static let transitionMonitoringInterval: TimeInterval = 30
    static let transitionWindow: TimeInterval = 2 * 60
    /// A point older than this is no longer trusted as a live position.
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

    /// A search made for "now" should be started immediately, even when the
    /// first available service leaves later. Planning is reserved for an
    /// explicitly future request; a minute of tolerance absorbs DatePicker's
    /// seconds and keeps the action from feeling arbitrary at the boundary.
    static func isFutureJourneyRequest(
        requestedAt: Date?,
        at now: Date
    ) -> Bool {
        guard let requestedAt else { return false }
        return requestedAt.timeIntervalSince(now) > futureJourneyRequestTolerance
    }

    /// Resolves the detail screen's context without letting a future-search
    /// preference override a departure that is already ready to start. An
    /// existing active session always wins; opening the saved draft explicitly
    /// turns it back into Go.
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
        if prefersPlan, activeAction == .plan { return .plan }
        return activeAction
    }

    static func schedule(for journey: Journey) -> [JourneySectionSchedule] {
        var cursor = journey.departureAt

        return journey.sections.enumerated().map { index, section in
            let startsAt = section.departureAt ?? cursor
            let durationEnd = startsAt.addingTimeInterval(TimeInterval(max(0, section.durationSeconds)))
            let endsAt = max(section.arrivalAt ?? durationEnd, startsAt)
            cursor = endsAt
            return JourneySectionSchedule(
                section: section,
                path: journey.path(at: index),
                startsAt: startsAt,
                endsAt: endsAt
            )
        }
    }

    /// The sections whose departure the traveller may still re-pick.
    ///
    /// One rule, because three surfaces asked the same question and answered it
    /// differently: the planning screen ("is it in the future?"), the guidance
    /// panel ("…and not behind the current section, and not the leg I am riding"), and
    /// the server, which decides which sections get choices at all. The
    /// planning screen simply has no current section, which is why the same
    /// function serves both.
    ///
    /// Riding a leg is the interesting case: swapping the train you are already
    /// on is not a choice the traveller can act on, so it is offered only while
    /// tracking says they are not yet aboard.
    static func revisableSectionIDs(
        in journey: Journey,
        currentSectionIndex: Int?,
        isTracking: Bool,
        at now: Date
    ) -> Set<String> {
        var revisable: Set<String> = []
        for (index, section) in journey.sections.enumerated() {
            guard let departureAt = section.departureAt, departureAt > now else { continue }
            if let currentSectionIndex {
                guard index >= currentSectionIndex else { continue }
                if isTracking, index == currentSectionIndex, section.kind == .transit {
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
