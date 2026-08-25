import SwiftUI

struct NaturalJourneyCriteriaView: View {
    let criteria: NaturalJourneyCriteria
    let journeyCount: Int
    let onEditOrigin: () -> Void
    let onEditDestination: () -> Void
    let onEditTime: () -> Void
    let onEditOptions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary)
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    OptionChip(
                        title: criteria.originLabel,
                        systemImage: "location.fill",
                        isActive: true,
                        action: onEditOrigin,
                    )
                    OptionChip(
                        title: criteria.destinationResult.name,
                        systemImage: "mappin.and.ellipse",
                        isActive: true,
                        action: onEditDestination,
                    )
                    OptionChip(
                        title: NaturalJourneyCriteria.timeLabel(
                            criteria.requestedAt,
                            represents: criteria.datetimeRepresents,
                            anchor: criteria.timeAnchor,
                        ),
                        systemImage: criteria.timeAnchor == .lastOfDay
                            ? "moon.stars"
                            : "calendar.badge.clock",
                        isActive: true,
                        action: onEditTime,
                    )

                    ForEach(criteria.requiredModes.sorted(), id: \.self) { mode in
                        modeChip("\(mode.naturalLanguageName) uniquement", systemImage: "checkmark.circle")
                    }
                    ForEach(criteria.excludedModes.sorted(), id: \.self) { mode in
                        modeChip("Sans \(mode.naturalLanguageName)", systemImage: "nosign")
                    }
                    ForEach(criteria.preferredModes.sorted(), id: \.self) { mode in
                        modeChip("Plutôt \(mode.naturalLanguageName)", systemImage: "heart")
                    }

                    modeChip("Options", systemImage: "slider.horizontal.3")
                }
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
    }

    private var summary: String {
        let noun = journeyCount > 1 ? "trajets" : "trajet"
        if criteria.timeAnchor == .lastOfDay {
            return "\(journeyCount) \(noun) — dernier départ de la journée"
        }
        let verb = criteria.datetimeRepresents == .arrival ? "pour arriver avant" : "au départ après"
        return "\(journeyCount) \(noun) \(verb) \(JourneyFormatting.time(criteria.requestedAt))"
    }

    private func modeChip(_ title: String, systemImage: String) -> some View {
        OptionChip(
            title: title,
            systemImage: systemImage,
            isActive: true,
            action: onEditOptions,
        )
    }
}
