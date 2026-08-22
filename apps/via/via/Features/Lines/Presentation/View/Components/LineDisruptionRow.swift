import SwiftUI

/// One perturbation, in one line: where it bites and until when. The wall of
/// text behind it — cause, official message, every period — waits in the sheet
/// this row opens, because a rider checking their line wants the *where*
/// first.
struct LineDisruptionRow: View {
    let disruption: LineDisruption
    let action: () -> Void

    var body: some View {
        // Both strings feed the row *and* its VoiceOver label, and `timingText`
        // formats dates — resolve each once per row rather than twice.
        let scope = disruption.scopeText
        let timing = disruption.timingText

        LineDisclosureRow(
            glyph: .symbol(
                disruption.condition.systemImage,
                tint: disruption.isActive ? disruption.condition.tint : Color.secondary
            ),
            title: scope,
            titleWeight: .medium,
            subtitle: timing,
            accessibilityLabel: [disruption.condition.title, scope, timing]
                .compactMap { $0 }
                .joined(separator: ", "),
            accessibilityHint: "Afficher le détail",
            action: action
        )
    }
}

extension LineDisruption {
    /// What the rider needs to place the perturbation on their own trip.
    var scopeText: String {
        let named = impactedSections.compactMap(\.travelText)
        switch named.count {
        case 0: return title ?? "Toute la ligne"
        case 1: return named[0]
        default: return "\(named.count) tronçons concernés"
        }
    }

    /// One period is enough for a row: the running one when it is running, the
    /// next one otherwise.
    var timingText: String? {
        let now = Date.now
        let period = isActive
            ? periods.first { $0.beginsAt <= now && now <= $0.endsAt } ?? periods.first
            : periods.first { $0.beginsAt > now } ?? periods.first
        guard let period else { return nil }

        let calendar = Calendar.current
        if isActive {
            return calendar.isDate(period.endsAt, inSameDayAs: now)
                ? "Jusqu’à \(period.endsAt.formatted(date: .omitted, time: .shortened))"
                : "Jusqu’au \(period.endsAt.formatted(date: .abbreviated, time: .omitted))"
        }
        if calendar.isDate(period.beginsAt, inSameDayAs: now) {
            return "À partir de \(period.beginsAt.formatted(date: .omitted, time: .shortened))"
        }
        return "Du \(period.beginsAt.formatted(date: .abbreviated, time: .omitted))"
            + " au \(period.endsAt.formatted(date: .abbreviated, time: .omitted))"
    }
}

extension LineImpactedSection {
    /// "La Défense → Nation", or nil when the feed named no usable pair.
    var travelText: String? {
        guard !fromName.isEmpty, !toName.isEmpty, fromName != toName else { return nil }
        return "\(fromName) → \(toName)"
    }
}
