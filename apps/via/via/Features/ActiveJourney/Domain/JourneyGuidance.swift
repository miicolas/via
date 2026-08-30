import Foundation

/// The single sentence that answers "what am I doing right now?".
///
/// Derived once and reused by the sticky guidance header, the tab bar accessory
/// and the Live Activity, so the three never disagree.
struct JourneyGuidanceHeadline: Sendable, Hashable {
    let title: String
    let detail: String?
    let symbolName: String
    let route: JourneyRoute?
}

enum JourneyGuidance {
    static func headline(
        journey: Journey,
        schedule: [JourneySectionSchedule],
        sectionIndex: Int,
        at date: Date,
        isPaused: Bool,
        liveStopProgress: JourneyStopProgress? = nil
    ) -> JourneyGuidanceHeadline {
        if isPaused {
            return JourneyGuidanceHeadline(
                title: "Trajet en pause",
                detail: "Reprenez pour relancer le suivi",
                symbolName: "pause.circle.fill",
                route: nil
            )
        }

        if date < journey.departureAt {
            return JourneyGuidanceHeadline(
                title: "Départ dans \(JourneyFormatting.countdown(journey.departureAt.timeIntervalSince(date)))",
                detail: "Arrivée prévue à \(JourneyFormatting.time(journey.arrivalAt))",
                symbolName: "clock.fill",
                route: schedule.first?.section.route
            )
        }

        guard schedule.indices.contains(sectionIndex) else {
            return arrived(at: journey)
        }

        let section = schedule[sectionIndex].section
        let endsAt = schedule[sectionIndex].endsAt

        switch section.kind {
        case .transit:
            return riding(
                section: section,
                endsAt: endsAt,
                liveStopProgress: liveStopProgress?.sectionID == section.id
                    ? liveStopProgress
                    : nil
            )
        case .walk, .bike, .transfer, .wait:
            guard let title = JourneySectionNarration.sentence(
                for: section,
                voice: .guidance
            ) else { return arrived(at: journey) }
            let detail = switch section.kind {
            case .transfer:
                "\(JourneyFormatting.duration(section.durationSeconds)) de marche"
            case .wait:
                "Départ à \(JourneyFormatting.time(endsAt))"
            default:
                "\(JourneyFormatting.duration(section.durationSeconds)) · arrivée à \(JourneyFormatting.time(endsAt))"
            }
            return JourneyGuidanceHeadline(
                title: title,
                detail: detail,
                symbolName: section.kind.systemImage,
                route: nil
            )
        }
    }

    private static func riding(
        section: JourneySection,
        endsAt: Date,
        liveStopProgress: JourneyStopProgress?
    ) -> JourneyGuidanceHeadline {
        let alightName = liveStopProgress?.alightingStopName
            ?? section.stops.last?.name
            ?? section.to.name
        let title: String
        if liveStopProgress?.remainingStopCount == 0 {
            title = "Descendez maintenant · \(alightName)"
        } else if liveStopProgress?.remainingStopCount == 1 {
            title = "Prochain arrêt · \(alightName)"
        } else {
            title = "Descendre à \(alightName)"
        }

        let destinationDetail = section.exit.map(exitLabel) ?? alightName
        let carriage = section.boardingPosition.map { "Voiture \($0.car)/\($0.carCount)" }
        let remainingStops = liveStopProgress.flatMap { progress -> String? in
            guard progress.remainingStopCount > 1 else { return nil }
            return "\(progress.remainingStopCount) arrêts"
        }
        let preparation = liveStopProgress?.remainingStopCount == 1
            ? "Préparez-vous à descendre"
            : nil
        let detail = [remainingStops, preparation, carriage, destinationDetail, JourneyFormatting.time(endsAt)]
            .compactMap { $0 }
            .joined(separator: " · ")

        return JourneyGuidanceHeadline(
            title: title,
            detail: detail,
            symbolName: section.route?.mode.chipSystemImage ?? "tram.fill",
            route: section.route
        )
    }

    /// Short enough for a Live Activity line: the number when there is one.
    static func exitLabel(_ exit: JourneyExit) -> String {
        exit.number.map { "Sortie \($0)" } ?? "Sortie \(exit.name)"
    }

    private static func arrived(at journey: Journey) -> JourneyGuidanceHeadline {
        JourneyGuidanceHeadline(
            title: "Vous êtes arrivé",
            detail: journey.sections.last?.to.name,
            symbolName: "flag.checkered",
            route: nil
        )
    }
}
