import SwiftUI

/// Wheelchair-accessibility badge. The tint carries the degree of autonomy the
/// station offers, the popover says what that degree means on the ground.
struct PMRBadgeView: View {
    let condition: AccessibilityCondition
    let label: String
    var comment: String?
    var size: CGFloat = 22
    var isInteractive: Bool = true

    private var message: String {
        guard let comment, !comment.isEmpty else { return condition.explanation }
        return "\(condition.explanation)\n\n\(comment)"
    }

    var body: some View {
        InfoBadgeButton(
            symbol: "figure.roll",
            tint: condition.tint,
            size: size,
            isInteractive: isInteractive,
            title: "Accessibilité PMR",
            message: message,
            accessibilityLabel: "Accessibilité PMR",
            accessibilityValue: accessibilityValue
        )
    }

    var accessibilityValue: String {
        guard let comment, !comment.isEmpty else { return label }
        return "\(label). \(comment)"
    }
}

/// How the degree reads on screen. It hangs off the domain value itself, so a
/// journey badge and a station badge cannot word or colour the same degree
/// differently.
extension AccessibilityCondition {
    var tint: Color {
        switch self {
        case .autonomous: .green
        case .staffAssistance: .blue
        case .reservationRequired: .orange
        }
    }

    var explanation: String {
        switch self {
        case .autonomous: "Praticable en fauteuil sans aide."
        case .staffAssistance: "Un agent vous accompagne sur une partie du trajet."
        case .reservationRequired: "Accompagnement à réserver auprès du transporteur."
        }
    }
}

#Preview {
    HStack(spacing: 10) {
        ForEach(AccessibilityCondition.allCases, id: \.self) { condition in
            PMRBadgeView(condition: condition, label: "En autonomie", size: 24)
        }
    }
    .padding()
}
