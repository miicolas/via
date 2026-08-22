import SwiftUI

/// A branch of the plan, folded into one row: its name, how many stations it
/// carries, and whether anything is wrong on it. The stations themselves only
/// unfold on a tap — a line with five branches is five rows, not two hundred.
struct LineBranchRow: View {
    let name: String
    let stopCount: Int
    let condition: LineCondition?
    let lineColor: Color
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        LineDisclosureRow(
            glyph: .disc("arrow.triangle.branch", tint: lineColor),
            title: "Branche \(name)",
            subtitle: subtitle,
            subtitleTint: condition?.tint ?? Color.secondary,
            isOpen: isOpen,
            accessibilityLabel: "Branche \(name), \(subtitle)",
            accessibilityValue: isOpen ? "Dépliée" : "Repliée",
            accessibilityHint: isOpen ? "Replier les gares" : "Déplier les gares",
            action: action
        )
    }

    private var subtitle: String {
        let stations = "\(stopCount) gare\(stopCount > 1 ? "s" : "")"
        guard let condition else { return stations }
        return "\(stations) · \(condition.title)"
    }
}

#Preview {
    VStack(spacing: 0) {
        LineBranchRow(
            name: "Cergy le Haut",
            stopCount: 9,
            condition: nil,
            lineColor: .red,
            isOpen: false,
            action: {}
        )
        LineBranchRow(
            name: "Poissy",
            stopCount: 5,
            condition: .suspended,
            lineColor: .red,
            isOpen: true,
            action: {}
        )
    }
    .padding()
}
