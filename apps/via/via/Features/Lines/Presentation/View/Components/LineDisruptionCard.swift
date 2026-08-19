import SwiftUI

struct LineDisruptionCard: View {
    let disruption: LineDisruption

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LineConditionLabel(condition: disruption.condition)

                Text(disruption.isActive ? "En cours" : "À venir")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(disruption.isActive ? disruption.condition.tint : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        (disruption.isActive ? disruption.condition.tint : Color.secondary)
                            .opacity(0.12)
                    )
                    .clipShape(Capsule())
            }

            if let title = disruption.title {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LineDisruptionImpactView(sections: disruption.impactedSections)

            if let period = displayedPeriod {
                Label(periodText(period), systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message = disruption.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let updatedAt = disruption.updatedAt {
                Text("Mis à jour à \(updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var backgroundColor: Color {
        if disruption.isActive {
            return disruption.condition.tint.opacity(0.10)
        }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }

    /// One period is enough for the card: the running one for an active
    /// disruption, the next one otherwise.
    private var displayedPeriod: LineDisruptionPeriod? {
        let now = Date.now
        if disruption.isActive {
            return disruption.periods.first { $0.beginsAt <= now && now <= $0.endsAt }
                ?? disruption.periods.first
        }
        return disruption.periods.first { $0.beginsAt > now } ?? disruption.periods.first
    }

    private func periodText(_ period: LineDisruptionPeriod) -> String {
        let begins = period.beginsAt.formatted(date: .abbreviated, time: .shortened)
        let ends = period.endsAt.formatted(date: .abbreviated, time: .shortened)
        return disruption.isActive ? "Jusqu’au \(ends)" : "Du \(begins) au \(ends)"
    }
}

#Preview("Travaux à venir") {
    ScrollView {
        VStack(spacing: 12) {
            LineDisruptionCard(
                disruption: PreviewLineStatusRepository.metro1Detail.disruptions
                    .first(where: { !$0.isActive })!
            )
        }
        .padding()
    }
}
