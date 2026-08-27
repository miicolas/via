import SwiftUI

extension Color {
    /// The transit hex the API ships, rebuilt for the widget extension, which
    /// does not link the app's `Color(transitHex:fallback:)`.
    init(widgetHex value: String?, fallback: Color) {
        guard let value else {
            self = fallback
            return
        }

        let hexadecimal = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hexadecimal.count == 6, let rawValue = UInt64(hexadecimal, radix: 16) else {
            self = fallback
            return
        }

        self.init(
            .sRGB,
            red: Double((rawValue >> 16) & 0xFF) / 255,
            green: Double((rawValue >> 8) & 0xFF) / 255,
            blue: Double(rawValue & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension WidgetLineCondition {
    /// The same four colours the Lignes tab uses, so a line reads identically
    /// on the Home Screen and in the app.
    var tint: Color {
        switch self {
        case .normal: .green
        case .attention: .yellow
        case .disrupted: .orange
        case .suspended: .red
        }
    }
}

extension WidgetLineStatus {
    /// The mark drawn on the badge: the condition when the line is disrupted
    /// now, a calendar when only a closure is coming, nothing when all is well.
    var indicatorCondition: WidgetLineCondition? {
        if condition.isDisrupted { return condition }
        return hasUpcomingClosure ? .attention : nil
    }

    var indicatorSystemImage: String {
        condition.isDisrupted ? condition.systemImage : "calendar.badge.exclamationmark"
    }

    /// What VoiceOver reads after the line name.
    var accessibilityValue: String {
        if condition.isDisrupted { return summary ?? condition.title }
        return hasUpcomingClosure ? "Fermeture prévue" : WidgetLineCondition.normal.title
    }
}
