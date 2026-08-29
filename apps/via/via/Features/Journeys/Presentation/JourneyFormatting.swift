import Foundation

enum JourneyFormatting {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func duration(_ seconds: Int) -> String {
        let minutes = max(0, Int(ceil(Double(seconds) / 60)))
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remaining = minutes % 60
        guard remaining > 0 else { return "\(hours) h" }
        return String(format: "%d h %02d", hours, remaining)
    }

    static func countdown(_ interval: TimeInterval) -> String {
        let minutes = max(1, Int(ceil(interval / 60)))
        return minutes >= 60 ? duration(minutes * 60) : "\(minutes) min"
    }

    static func carbonEmission(grams: Double) -> String {
        carbon(grams: grams, kilogramUnit: "kg CO₂e", gramUnit: "g CO₂e")
    }

    static func carbonEmissionAccessibility(grams: Double) -> String {
        carbon(grams: grams, kilogramUnit: "kilogrammes de CO₂e", gramUnit: "grammes de CO₂e")
    }

    static func fare(amountInCents: Int) -> String {
        let amount = max(0, amountInCents)
        let euros = amount / 100
        let cents = amount % 100
        guard cents > 0 else { return "\(euros) €" }
        return String(format: "%d,%02d €", euros, cents)
    }

    static func fareAccessibility(amountInCents: Int) -> String {
        let amount = max(0, amountInCents)
        let euros = amount / 100
        let cents = amount % 100
        let euroUnit = euros > 1 ? "euros" : "euro"
        guard cents > 0 else { return "\(euros) \(euroUnit)" }
        let centUnit = cents > 1 ? "centimes" : "centime"
        return "\(euros) \(euroUnit) et \(cents) \(centUnit)"
    }

    /// One rounding rule for the number the eye reads and the one VoiceOver
    /// speaks: only the unit differs, and two copies would let them disagree
    /// about the same estimate.
    private static func carbon(grams: Double, kilogramUnit: String, gramUnit: String) -> String {
        let value = max(0, grams)
        if value >= 1_000 {
            return "\(number(value / 1_000, maximumFractionDigits: 1)) \(kilogramUnit)"
        }
        return "\(number(value, maximumFractionDigits: value < 10 ? 1 : 0)) \(gramUnit)"
    }

    /// Under 50 m the exit is right there and a number is noise. Above it, the
    /// walk is rounded to the nearest 50 m — the planner's metre is a guess and
    /// reading it back exactly would claim a precision it does not have.
    static func exitDistance(meters: Int?) -> String? {
        guard let meters, meters >= 50 else { return nil }
        let rounded = meters >= 1_000 ? Double(meters) : Double((meters + 25) / 50 * 50)
        return DistanceFormatting.text(meters: rounded)
    }

    static func boardingPositionAccessibilityLabel(
        _ position: JourneyBoardingPosition
    ) -> String {
        let zone = switch position.zone {
        case .front: "en tête"
        case .middle: "au milieu"
        case .rear: "en queue"
        }
        let purpose = switch position.reason {
        case .exit: "pour la sortie"
        case .transfer: "pour la correspondance"
        }
        let equipment = switch position.equipment {
        case .escalator: ", escalator"
        case .lift: ", ascenseur"
        case .stairs: ", escalier"
        case nil: ""
        }
        return "Position recommandée, montez \(zone) du train, voiture "
            + "\(position.car) sur \(position.carCount), \(purpose)\(equipment)"
    }

    static func exitAccessibilityLabel(
        name: String,
        number: Int?,
        walkingMeters: Int?
    ) -> String {
        let number = number.map { "Sortie numéro \($0), " } ?? "Sortie "
        let distance = exitDistance(meters: walkingMeters)
            .map { ", à environ \($0) de votre destination" } ?? ""
        return "Sortie recommandée, \(number)\(name)\(distance)"
    }

    private static func number(_ value: Double, maximumFractionDigits: Int) -> String {
        let scale = pow(10.0, Double(maximumFractionDigits))
        let rounded = (value * scale).rounded(.toNearestOrAwayFromZero) / scale
        return rounded.formatted(
            .number
                .precision(.fractionLength(0...maximumFractionDigits))
                .locale(Locale(identifier: "fr_FR"))
        )
    }
}
