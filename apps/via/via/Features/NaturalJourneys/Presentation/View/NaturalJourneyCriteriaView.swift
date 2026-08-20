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
                    chip(criteria.originLabel, systemImage: "location.fill", action: onEditOrigin)
                    chip(criteria.destinationResult.name, systemImage: "mappin.and.ellipse", action: onEditDestination)
                    chip(timeLabel, systemImage: "calendar.badge.clock", action: onEditTime)

                    ForEach(criteria.requiredModes.sorted(), id: \.self) { mode in
                        chip("\(mode.naturalLanguageName) uniquement", systemImage: "checkmark.circle", action: onEditOptions)
                    }
                    ForEach(criteria.excludedModes.sorted(), id: \.self) { mode in
                        chip("Sans \(mode.naturalLanguageName)", systemImage: "nosign", action: onEditOptions)
                    }
                    ForEach(criteria.preferredModes.sorted(), id: \.self) { mode in
                        chip("Plutôt \(mode.naturalLanguageName)", systemImage: "heart", action: onEditOptions)
                    }

                    chip("Options", systemImage: "slider.horizontal.3", action: onEditOptions)
                }
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
    }

    private var summary: String {
        let count = journeyCount
        let noun = count > 1 ? "trajets" : "trajet"
        let verb = criteria.datetimeRepresents == .arrival ? "pour arriver avant" : "au départ après"
        let time = criteria.requestedAt.formatted(date: .omitted, time: .shortened)
        return "\(count) \(noun) \(verb) \(time)"
    }

    private var timeLabel: String {
        let meaning = criteria.datetimeRepresents == .arrival ? "Arrivée" : "Départ"
        return "\(meaning) · \(criteria.requestedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func chip(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Color.secondary.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Modifier ce critère")
    }
}
