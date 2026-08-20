import SwiftUI

struct NaturalJourneyPreservedCriteriaView: View {
    let criteria: NaturalJourneyCriteria

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Critères conservés")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    chip(criteria.originLabel, systemImage: "location.fill")
                    chip(criteria.destinationResult.name, systemImage: "mappin.and.ellipse")
                    chip(timeLabel, systemImage: "calendar.badge.clock")

                    if !criteria.requiredModes.isEmpty {
                        chip("Modes obligatoires conservés", systemImage: "checkmark.circle")
                    }
                    if !criteria.excludedModes.isEmpty {
                        chip("Modes exclus conservés", systemImage: "nosign")
                    }
                    if !criteria.preferredModes.isEmpty {
                        chip("Modes préférés conservés", systemImage: "heart")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
    }

    private var timeLabel: String {
        let meaning = criteria.datetimeRepresents == .arrival ? "Arrivée" : "Départ"
        let value = criteria.requestedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(meaning) · \(value)"
    }

    private func chip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.secondary.opacity(0.10), in: Capsule())
    }
}
