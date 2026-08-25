import Foundation

/// The shape of the route, derived once from its sections.
enum JourneyShape: Sendable, Hashable {
    case transit
    case walking
    case cycling
    case walkingAndCycling

    static func of(_ journey: Journey) -> Self {
        let kinds = journey.sections.map(\.kind)
        guard !kinds.isEmpty else { return .transit }

        let isSelfPowered = kinds.allSatisfy { $0 == .walk || $0 == .bike }
        guard isSelfPowered else { return .transit }
        if kinds.contains(.bike) {
            return kinds.contains(.walk) ? .walkingAndCycling : .cycling
        }
        return .walking
    }

    var isDirectPath: Bool {
        switch self {
        case .walking, .cycling, .walkingAndCycling: true
        case .transit: false
        }
    }

    var isBikeOnly: Bool {
        switch self {
        case .cycling, .walkingAndCycling: true
        case .transit, .walking: false
        }
    }

    static func primarySection(of journey: Journey) -> JourneySection? {
        journey.sections.first { $0.kind != .wait && $0.kind != .transfer }
    }
}

/// Shared wording for the movement sections shown in guidance, timelines and
/// accessibility labels. The voice is explicit because the screens use
/// different grammatical forms while still describing the same action.
enum JourneySectionNarration {
    enum Voice: Sendable, Hashable {
        case guidance
        case timeline
    }

    static func sentence(for section: JourneySection, voice: Voice) -> String? {
        switch section.kind {
        case .walk:
            return voice == .guidance
                ? "Marchez jusqu’à \(section.to.name)"
                : "Marcher jusqu’à \(section.to.name)"
        case .bike:
            return voice == .guidance
                ? "Pédalez jusqu’à \(section.to.name)"
                : "Pédaler jusqu’à \(section.to.name)"
        case .wait:
            return voice == .guidance
                ? "Patientez à \(section.from.name)"
                : "Attendre à \(section.from.name)"
        case .transfer:
            return voice == .guidance
                ? "Rejoignez \(section.to.name)"
                : "Correspondance vers \(section.to.name)"
        case .transit:
            return nil
        }
    }

    static func movementSentence(for section: JourneySection, voice: Voice) -> String {
        guard let sentence = sentence(for: section, voice: voice) else {
            preconditionFailure("Transit sections do not have movement narration")
        }
        return sentence
    }

    static func sentence(for kind: JourneyTimelineNode.Kind, voice: Voice) -> String? {
        switch kind {
        case .walk(let destination):
            return voice == .guidance
                ? "Marchez jusqu’à \(destination)"
                : "Marcher jusqu’à \(destination)"
        case .bike(let destination):
            return voice == .guidance
                ? "Pédalez jusqu’à \(destination)"
                : "Pédaler jusqu’à \(destination)"
        case .wait(let place):
            return voice == .guidance
                ? "Patientez à \(place)"
                : "Attendre à \(place)"
        case .transfer(let destination):
            return voice == .guidance
                ? "Rejoignez \(destination)"
                : "Correspondance vers \(destination)"
        case .origin, .destination, .board, .alight, .ride:
            return nil
        }
    }

    static func movementSentence(for kind: JourneyTimelineNode.Kind, voice: Voice) -> String {
        guard let sentence = sentence(for: kind, voice: voice) else {
            preconditionFailure("Station nodes do not have movement narration")
        }
        return sentence
    }

    static func accessibilitySentence(
        for kind: JourneyTimelineNode.Kind,
        duration: String
    ) -> String {
        switch kind {
        case .walk(_):
            "Marcher (duration) jusqu’à (destination)"
        case .bike(let destination):
            "Pédaler (duration) jusqu’à (destination)"
        case .wait(let place):
            "Attendre (duration) à (place)"
        case .transfer(let destination):
            "Correspondance de (duration) vers (destination)"
        case .origin, .destination, .board, .alight, .ride:
            preconditionFailure("Station nodes do not have movement accessibility narration")
        }
    }
}
