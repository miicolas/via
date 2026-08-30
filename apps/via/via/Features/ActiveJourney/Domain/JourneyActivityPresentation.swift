import Foundation

/// The spoken/system-alert copy for one essential Live Activity update.
/// ActivityKit owns delivery, sound, Focus behavior, and presentation.
struct JourneyActivityAlert: Sendable, Equatable {
    let title: String
    let body: String
}

/// Builds every Live Activity payload from explicit journey state.
///
/// The lock screen says the same sentence as the guidance header and the tab
/// bar accessory, from the same derivation: the headline is recomputed here
/// through `JourneyGuidance` with the very inputs the header uses, so the two
/// cannot drift apart.
enum JourneyActivityPresentation {
    static func contentState(
        session: ActiveJourneySession,
        isArrived: Bool,
        requiresResume: Bool,
        isOffline: Bool,
        at date: Date,
        liveStopProgress: JourneyStopProgress? = nil
    ) -> JourneyActivityAttributes.ContentState {
        let journey = session.journey
        let statePhase: JourneyActivityAttributes.Phase
        let phaseTitle: String
        if isArrived {
            statePhase = .arrived
            phaseTitle = "Vous êtes arrivé"
        } else if requiresResume {
            statePhase = .paused
            phaseTitle = "Trajet en pause"
        } else if journey.departureAt.timeIntervalSince(date) > 0 {
            statePhase = .scheduled
            phaseTitle = "Départ"
        } else {
            statePhase = .underway
            phaseTitle = "En route"
        }

        let headline = JourneyGuidance.headline(
            journey: journey,
            schedule: ActiveJourneyRules.schedule(for: journey),
            sectionIndex: session.currentSectionIndex,
            at: date,
            isPaused: requiresResume,
            liveStopProgress: liveStopProgress
        )
        let instructionTitle: String
        let instructionDetail: String?
        if isArrived {
            instructionTitle = session.destination.name
            instructionDetail = nil
        } else if statePhase == .scheduled {
            // The countdown belongs to the system-rendered timer. Keep the
            // title stable so it does not freeze at the value from the last
            // app update.
            instructionTitle = "Trajet vers \(session.destination.name)"
            instructionDetail = headline.detail
        } else {
            instructionTitle = headline.title
            instructionDetail = headline.detail
        }

        let next = nextInstruction(in: session)
        let line = line(headline: headline, session: session)
        return JourneyActivityAttributes.ContentState(
            phaseTitle: phaseTitle,
            instructionTitle: instructionTitle,
            instructionDetail: instructionDetail,
            nextAction: isArrived ? nil : next?.title,
            line: isArrived ? nil : line,
            nextLine: isArrived ? nil : nextLine(after: next, currentLine: line),
            arrivalAt: journey.arrivalAt,
            isOffline: isArrived ? false : isOffline,
            isArrived: isArrived,
            phase: statePhase,
            departureAt: journey.departureAt,
            stopProgress: statePhase == .underway
                ? liveStopProgress.map(activityStopProgress)
                : nil
        )
    }

    /// Alerts only when the alighting instruction is actionable. Regular
    /// station updates still refresh the Live Activity silently.
    static func alightingAlert(
        for progress: JourneyStopProgress
    ) -> JourneyActivityAlert? {
        switch progress.remainingStopCount {
        case 0:
            JourneyActivityAlert(
                title: "Descendez maintenant",
                body: "Vous êtes à \(progress.alightingStopName)."
            )
        case 1:
            JourneyActivityAlert(
                title: "Prochain arrêt · \(progress.alightingStopName)",
                body: "Préparez-vous à descendre."
            )
        default:
            nil
        }
    }

    static func terminal(
        title: String,
        session: ActiveJourneySession
    ) -> JourneyActivityAttributes.ContentState {
        JourneyActivityAttributes.ContentState(
            phaseTitle: title,
            instructionTitle: session.destination.name,
            instructionDetail: nil,
            nextAction: nil,
            line: nil,
            nextLine: nil,
            arrivalAt: session.journey.arrivalAt,
            isOffline: false,
            isArrived: false,
            phase: .ended,
            departureAt: session.journey.departureAt
        )
    }

    /// The look-ahead step the Live Activity shows on its "Ensuite" line.
    static func nextInstruction(in session: ActiveJourneySession) -> ActiveJourneyInstruction? {
        instruction(at: session.currentSectionIndex + 1, in: session)
    }

    static func staleDate(for journey: Journey, at date: Date) -> Date {
        let interval = ActiveJourneyRules.nextMonitoringDelay(in: journey, at: date)
        return date.addingTimeInterval(max(45, interval * 1.5))
    }

    private static func activityStopProgress(
        _ progress: JourneyStopProgress
    ) -> JourneyActivityAttributes.StopProgress {
        let status: JourneyActivityAttributes.StopProgress.Status = switch progress.status {
        case .current: .current
        case .next: .next
        }
        return JourneyActivityAttributes.StopProgress(
            stopName: progress.stopName,
            alightingStopName: progress.alightingStopName,
            remainingStopCount: progress.remainingStopCount,
            status: status
        )
    }

    private static func instruction(
        at index: Int,
        in session: ActiveJourneySession
    ) -> ActiveJourneyInstruction? {
        guard session.journey.sections.indices.contains(index) else { return nil }
        let section = session.journey.sections[index]
        let title: String
        let detail: String?

        switch section.kind {
        case .walk, .bike, .wait, .transfer:
            title = JourneySectionNarration.movementSentence(for: section, voice: .guidance)
            detail = if section.kind == .transfer {
                section.durationSeconds > 0
                    ? "Correspondance · \(JourneyFormatting.duration(section.durationSeconds))"
                    : "Correspondance"
            } else {
                section.durationSeconds > 0
                    ? JourneyFormatting.duration(section.durationSeconds)
                    : nil
            }
        case .transit:
            title = section.route.map { "Prenez \($0.longName)" } ?? "Prenez le transport"
            let direction = section.direction.map { "Direction \($0)" }
            let platform = section.platform.map { "Quai \($0)" }
            // Where to stand comes before where to leave: one is acted on now,
            // on this platform, the other several stops later.
            let car = section.boardingPosition.map { "Voiture \($0.car)/\($0.carCount)" }
            let exit = section.exit.map(JourneyGuidance.exitLabel)
            detail = [direction, platform, car, exit]
                .compactMap { $0 }
                .joined(separator: " · ")
                .nilIfEmpty
        }

        return ActiveJourneyInstruction(
            title: title,
            detail: detail,
            route: section.route,
            startsAt: section.departureAt,
            endsAt: section.arrivalAt,
            stops: section.stops,
            sectionKind: section.kind
        )
    }

    /// The line the Live Activity puts forward: the one being ridden, or the
    /// one the current walk or wait leads to, so the badge survives the legs
    /// that have no route of their own.
    private static func line(
        headline: JourneyGuidanceHeadline,
        session: ActiveJourneySession
    ) -> JourneyActivityAttributes.LineBadge? {
        (headline.route ?? upcomingRoute(in: session))
            .map { JourneyActivityAttributes.LineBadge(route: $0) }
    }

    /// Only worth a badge on the "Ensuite" line when it is not the line already
    /// shown for the current step.
    private static func nextLine(
        after next: ActiveJourneyInstruction?,
        currentLine: JourneyActivityAttributes.LineBadge?
    ) -> JourneyActivityAttributes.LineBadge? {
        guard let route = next?.route else { return nil }
        let badge = JourneyActivityAttributes.LineBadge(route: route)
        return badge == currentLine ? nil : badge
    }

    private static func upcomingRoute(in session: ActiveJourneySession) -> JourneyRoute? {
        let sections = session.journey.sections
        let index = max(0, session.currentSectionIndex)
        guard sections.indices.contains(index) else { return nil }
        return sections[index...].first { $0.kind == .transit }?.route
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension JourneyActivityAttributes.LineBadge {
    init(route: JourneyRoute) {
        self.init(
            shortName: route.shortName,
            colorHex: route.colorHex,
            textColorHex: route.textColorHex
        )
    }
}
