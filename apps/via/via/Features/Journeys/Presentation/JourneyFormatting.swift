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
}
