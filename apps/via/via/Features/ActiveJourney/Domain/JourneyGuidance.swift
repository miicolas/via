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
        case .walk:
            return JourneyGuidanceHeadline(
                title: "Marcher jusqu'à \(section.to.name)",
                detail: "\(JourneyFormatting.duration(section.durationSeconds)) · arrivée à \(JourneyFormatting.time(endsAt))",
                symbolName: "figure.walk",
                route: nil,
                stopsUntilAlighting: nil,
                alightStopName: nil
            )
        case .transfer:
            return JourneyGuidanceHeadline(
                title: "Correspondance vers \(section.to.name)",
                detail: "\(JourneyFormatting.duration(section.durationSeconds)) de marche",
                symbolName: "arrow.triangle.turn.up.right.diamond",
                route: nil,
                stopsUntilAlighting: nil,
                alightStopName: nil
            )
        case .wait:
            return JourneyGuidanceHeadline(
                title: "Attendre à \(section.from.name)",
                detail: "Départ à \(JourneyFormatting.time(endsAt))",
                symbolName: "clock",
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

        return JourneyGuidanceHeadline(
            title: title,
            detail: progress.stopsUntilAlighting == nil
                ? "Arrivée à \(JourneyFormatting.time(endsAt))"
                : "\(alightName) · \(JourneyFormatting.time(endsAt))",
            symbolName: section.route?.mode.chipSystemImage ?? "tram.fill",
            route: section.route,
            stopsUntilAlighting: progress.stopsUntilAlighting,
            alightStopName: alightName
        )
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
