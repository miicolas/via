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

struct LineConditionLabel: View {
    let condition: LineCondition
    var compact: Bool = false

    var body: some View {
        if compact {
            Image(systemName: condition.systemImage)
                .foregroundStyle(condition.tint)
                .accessibilityLabel(condition.title)
        } else {
            Label(condition.title, systemImage: condition.systemImage)
                .font(.subheadline.weight(.medium))
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
