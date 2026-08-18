import SwiftUI

struct LineDisruptionCard: View {
    let disruption: LineDisruption

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LineConditionLabel(condition: disruption.condition)

            if let title = disruption.title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            if let message = disruption.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let period = displayedPeriod {
                Text(periodText(period))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let updatedAt = disruption.updatedAt {
                Text("Mis à jour à \(updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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

#Preview {
    List {
        ForEach(PreviewLineStatusRepository.metro1Detail.disruptions) { disruption in
            LineDisruptionCard(disruption: disruption)
        }
    }
}
