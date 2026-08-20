import SwiftUI

struct NaturalJourneyPreservedCriteriaView: View {
    private let source: Source

    init(criteria: NaturalJourneyCriteria) {
        source = .resolved(criteria)
    }

    init(draft: NaturalJourneyDraft) {
        source = .draft(draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Critères conservés")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    chip(originLabel, systemImage: "location.fill")
                    if let destinationLabel {
                        chip(destinationLabel, systemImage: "mappin.and.ellipse")
                    }
                    if let timeLabel {
                        chip(timeLabel, systemImage: "calendar.badge.clock")
                    }

                    if !requiredModes.isEmpty {
                        chip("Modes obligatoires conservés", systemImage: "checkmark.circle")
                    }
                    if !excludedModes.isEmpty {
                        chip("Modes exclus conservés", systemImage: "nosign")
                    }
                    if !preferredModes.isEmpty {
                        chip("Modes préférés conservés", systemImage: "heart")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
    }

    private var originLabel: String {
        switch source {
        case let .resolved(criteria):
            criteria.originLabel
        case let .draft(draft):
            switch draft.intent.origin {
            case .currentLocation: "Ma position"
            case let .place(query): draft.origin?.name ?? query
            }
        }
    }

    private var destinationLabel: String? {
        switch source {
        case let .resolved(criteria): criteria.destinationResult.name
        case let .draft(draft): draft.destination?.name ?? draft.intent.destinationQuery
        }
    }

    private var timeLabel: String? {
        let date: Date
        let meaning: JourneyDatetimeRepresents
        switch source {
        case let .resolved(criteria):
            date = criteria.requestedAt
            meaning = criteria.datetimeRepresents
        case let .draft(draft):
            guard let requestedAt = draft.intent.requestedAt else { return nil }
            date = requestedAt
            meaning = draft.intent.datetimeRepresents == .arrival ? .arrival : .departure
        }
        let prefix = meaning == .arrival ? "Arrivée" : "Départ"
        let value = date.formatted(date: .abbreviated, time: .shortened)
        return "\(prefix) · \(value)"
    }

    private var requiredModes: Set<TransitMode> {
        switch source {
        case let .resolved(criteria): criteria.requiredModes
        case let .draft(draft): draft.intent.requiredModes
        }
    }

    private var excludedModes: Set<TransitMode> {
        switch source {
        case let .resolved(criteria): criteria.excludedModes
        case let .draft(draft): draft.intent.excludedModes
        }
    }

    private var preferredModes: Set<TransitMode> {
        switch source {
        case let .resolved(criteria): criteria.preferredModes
        case let .draft(draft): draft.intent.preferredModes
        }
    }

    private func chip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.secondary.opacity(0.10), in: Capsule())
    }

    private enum Source {
        case resolved(NaturalJourneyCriteria)
        case draft(NaturalJourneyDraft)
    }
}
