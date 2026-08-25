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
    /// Stops left before the traveller must get off, when that applies.
    let stopsUntilAlighting: Int?
    /// Name of the stop to get off at, when the current leg is a ridden one.
    let alightStopName: String?
}

enum JourneyGuidance {
    static func headline(
        journey: Journey,
        schedule: [JourneySectionSchedule],
        progress: JourneyProgress,
        at date: Date,
        isPaused: Bool
    ) -> JourneyGuidanceHeadline {
        if isPaused {
            return JourneyGuidanceHeadline(
                title: "Trajet en pause",
                detail: "Reprenez pour relancer le suivi",
                symbolName: "pause.circle.fill",
                route: nil,
                stopsUntilAlighting: nil,
                alightStopName: nil
            )
        }

        if date < journey.departureAt {
            return JourneyGuidanceHeadline(
                title: "Départ dans \(JourneyFormatting.countdown(journey.departureAt.timeIntervalSince(date)))",
                detail: "Arrivée prévue à \(JourneyFormatting.time(journey.arrivalAt))",
                symbolName: "clock.fill",
                route: schedule.first?.section.route,
                stopsUntilAlighting: nil,
                alightStopName: nil
            )
        }

        guard schedule.indices.contains(progress.sectionIndex) else {
            return arrived(at: journey)
        }

        let section = schedule[progress.sectionIndex].section
        let endsAt = schedule[progress.sectionIndex].endsAt

        switch section.kind {
        case .transit:
            return riding(section: section, endsAt: endsAt, progress: progress)
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
                route: nil,
                stopsUntilAlighting: nil,
                alightStopName: nil
            )
        }
    }

    private static func riding(
        section: JourneySection,
        endsAt: Date,
        progress: JourneyProgress
    ) -> JourneyGuidanceHeadline {
        let alightName = section.stops.last?.name ?? section.to.name
        let title: String = switch progress.stopsUntilAlighting {
        case .none: "Descendre à \(alightName)"
        case .some(0): "Descendre maintenant"
        case .some(1): "Descendre au prochain arrêt"
        case .some(let remaining): "Descendre dans \(remaining) arrêts"
        }

        /**
         The exit replaces the alighting stop's name once it is nearly time to
         get off: a traveller two stops away already knows where they are going,
         and the door number is what they will need on the platform.
         */
        let leadsWithExit = section.exit != nil && (progress.stopsUntilAlighting ?? 99) <= 1
        let destinationDetail: String = if leadsWithExit, let exit = section.exit {
            exitLabel(exit)
        } else if progress.stopsUntilAlighting == nil {
            "Arrivée"
        } else {
            alightName
        }
        let carriage = section.boardingPosition.map { "Voiture \($0.car)/\($0.carCount)" }
        let detail = [carriage, destinationDetail, JourneyFormatting.time(endsAt)]
            .compactMap { $0 }
            .joined(separator: " · ")

        return JourneyGuidanceHeadline(
            title: title,
            detail: detail,
            symbolName: section.route?.mode.chipSystemImage ?? "tram.fill",
            route: section.route,
            stopsUntilAlighting: progress.stopsUntilAlighting,
            alightStopName: alightName
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
            route: nil,
            stopsUntilAlighting: nil,
            alightStopName: nil
        )
    }
}
