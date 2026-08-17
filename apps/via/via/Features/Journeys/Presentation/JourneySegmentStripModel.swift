import Foundation

struct JourneySegmentStripModel: Sendable, Equatable {
    struct Item: Sendable, Equatable, Identifiable {
        enum Kind: Sendable, Equatable {
            case walk
            case walkingOnly
            case wait
            case transfer
            case transit(
                line: String,
                mode: TransitMode?,
                colorHex: String,
                textColorHex: String
            )
        }

        let id: String
        let kind: Kind
        /// "6 min" — full duration, shown on transit pills and walking-only journeys.
        let durationLabel: String
        /// "6" — bare minute count, shown on the compact walk/wait/transfer chips.
        let minutesLabel: String

        var accessibilityLabel: String {
            switch kind {
            case .walk:
                "Marche, \(durationLabel)"
            case .walkingOnly:
                "\(durationLabel) à pied"
            case .wait:
                "Attente, \(durationLabel)"
            case .transfer:
                "Correspondance, \(durationLabel)"
            case .transit(let line, let mode, _, _):
                "\(mode?.displayName ?? "Ligne") \(line), \(durationLabel)"
            }
        }
    }

    let items: [Item]

    init(journey: Journey) {
        let nonzeroSections = journey.sections.filter {
            $0.durationSeconds > 0 || $0.kind == .transit || $0.kind == .walk
        }
        if !nonzeroSections.isEmpty,
           nonzeroSections.allSatisfy({ $0.kind == .walk }) {
            items = [Item(
                id: "walking-only",
                kind: .walkingOnly,
                durationLabel: Self.minutesLabel(journey.durationSeconds),
                minutesLabel: "\(Self.roundedMinutes(journey.durationSeconds))"
            )]
            return
        }

        items = nonzeroSections.map { section in
            let kind: Item.Kind = switch section.kind {
            case .walk:
                .walk
            case .wait:
                .wait
            case .transfer:
                .transfer
            case .transit:
                .transit(
                    line: section.route?.shortName ?? "?",
                    mode: section.route?.mode,
                    colorHex: section.route?.colorHex ?? "777777",
                    textColorHex: section.route?.textColorHex ?? "FFFFFF"
                )
            }
            return Item(
                id: section.id,
                kind: kind,
                durationLabel: Self.minutesLabel(section.durationSeconds),
                minutesLabel: "\(Self.roundedMinutes(section.durationSeconds))"
            )
        }
    }

    private static func roundedMinutes(_ seconds: Int) -> Int {
        max(1, Int(ceil(Double(max(0, seconds)) / 60)))
    }

    private static func minutesLabel(_ seconds: Int) -> String {
        guard seconds > 0 else { return "< 1 min" }
        return "\(roundedMinutes(seconds)) min"
    }
}

extension Journey {
    /// Whole minutes shown as the journey's total duration, rounded up, never zero.
    var totalDurationMinutes: Int {
        max(1, Int(ceil(Double(durationSeconds) / 60)))
    }

    var totalDurationLabel: String {
        "\(totalDurationMinutes) min"
    }
}
