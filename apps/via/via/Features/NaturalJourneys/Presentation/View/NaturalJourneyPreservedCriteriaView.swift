import SwiftUI

/// The recap shown when a search could not finish: what Via understood is kept
/// on screen so the traveller does not have to describe the trip again.
struct NaturalJourneyPreservedCriteriaView: View {
    private let fields: Fields

    init(criteria: NaturalJourneyCriteria) {
        fields = Fields(criteria)
    }

    init(draft: NaturalJourneyDraft) {
        fields = Fields(draft)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Critères conservés")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    NaturalJourneyCriteriaChip(
                        title: fields.origin,
                        systemImage: "location.fill",
                    )
                    if let destination = fields.destination {
                        NaturalJourneyCriteriaChip(
                            title: destination,
                            systemImage: "mappin.and.ellipse",
                        )
                    }
                    if let time = fields.time {
                        NaturalJourneyCriteriaChip(title: time, systemImage: "calendar.badge.clock")
                    }

                    if fields.hasRequiredModes {
                        NaturalJourneyCriteriaChip(
                            title: "Modes obligatoires conservés",
                            systemImage: "checkmark.circle",
                        )
                    }
                    if fields.hasExcludedModes {
                        NaturalJourneyCriteriaChip(
                            title: "Modes exclus conservés",
                            systemImage: "nosign",
                        )
                    }
                    if fields.hasPreferredModes {
                        NaturalJourneyCriteriaChip(
                            title: "Modes préférés conservés",
                            systemImage: "heart",
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    /// A resolved interpretation and a half-resolved draft describe the same
    /// trip; normalising once here keeps the body free of that distinction.
    private struct Fields {
        let origin: String
        let destination: String?
        let time: String?
        let hasRequiredModes: Bool
        let hasExcludedModes: Bool
        let hasPreferredModes: Bool

        init(_ criteria: NaturalJourneyCriteria) {
            origin = criteria.originLabel
            destination = criteria.destinationResult.name
            time = NaturalJourneyCriteria.timeLabel(
                criteria.requestedAt,
                represents: criteria.datetimeRepresents,
            )
            hasRequiredModes = !criteria.requiredModes.isEmpty
            hasExcludedModes = !criteria.excludedModes.isEmpty
            hasPreferredModes = !criteria.preferredModes.isEmpty
        }

        init(_ draft: NaturalJourneyDraft) {
            let intent = draft.intent
            origin = switch intent.origin {
            case .currentLocation: "Ma position"
            case let .place(query): draft.origin?.name ?? query
            }
            destination = draft.destination?.name ?? intent.destinationQuery
            time = intent.requestedAt.map {
                NaturalJourneyCriteria.timeLabel($0, represents: intent.datetimeRepresents.journeyMeaning)
            }
            hasRequiredModes = !intent.requiredModes.isEmpty
            hasExcludedModes = !intent.excludedModes.isEmpty
            hasPreferredModes = !intent.preferredModes.isEmpty
        }
    }
}
