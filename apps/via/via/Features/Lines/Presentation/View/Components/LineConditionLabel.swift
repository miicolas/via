import SwiftUI

extension LineCondition {
    /// Badge tint; never the only carrier of the state, a label rides along.
    var tint: Color {
        switch self {
        case .normal: .green
        case .attention: .yellow
        case .disrupted: .orange
        case .suspended: .red
        }
    }
}

/// The condition as a glyph on its own tinted disc — the network verdict at
/// the top of the Lines tab, where the wording sits beside the badge rather
/// than inside it.
struct LineConditionBadge: View {
    let condition: LineCondition

    var body: some View {
        Image(systemName: condition.systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(condition.tint)
            .frame(width: 44, height: 44)
            .background(condition.tint.opacity(0.12), in: .circle)
            .accessibilityHidden(true)
    }
}

struct LineConditionLabel: View {
    let condition: LineCondition
    var compact: Bool = false
    var font: Font = .subheadline.weight(.medium)

    var body: some View {
        if compact {
            Image(systemName: condition.systemImage)
                .foregroundStyle(condition.tint)
                .accessibilityLabel(condition.title)
        } else {
            Label(condition.title, systemImage: condition.systemImage)
                .font(font)
                .foregroundStyle(condition.tint)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(LineCondition.allCases, id: \.self) { condition in
            HStack(spacing: 16) {
                LineConditionLabel(condition: condition, compact: true)
                LineConditionLabel(condition: condition)
            }
        }
    }
    .padding()
}
