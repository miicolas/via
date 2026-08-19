import ActivityKit
import SwiftUI
import WidgetKit

struct JourneyActivityLockScreenView: View {
    let context: ActivityViewContext<JourneyActivityAttributes>

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: context.state.isArrived ? "checkmark.circle.fill" : "location.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(context.state.isArrived ? .green : .blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(context.state.phaseTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(context.state.isOffline ? .orange : .secondary)
                    Spacer(minLength: 8)
                    Text(context.state.arrivalAt, style: .time)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }

                Text(context.state.instructionTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let detail = context.state.instructionDetail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let nextAction = context.state.nextAction {
                    Text("Ensuite · \(nextAction)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}
