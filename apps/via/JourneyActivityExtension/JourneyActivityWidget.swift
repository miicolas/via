import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

@main
struct JourneyActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        JourneyActivityWidget()
    }
}

struct JourneyActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: JourneyActivityAttributes.self) { context in
            JourneyActivityLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.88))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    routeBadge(context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.arrivalAt, style: .time)
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phaseTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(context.state.isOffline ? .orange : .secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.state.instructionTitle)
                            .font(.headline)
                            .lineLimit(2)
                        if let detail = context.state.instructionDetail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                routeBadge(context.state)
            } compactTrailing: {
                Text(context.state.arrivalAt, style: .time)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: context.state.isArrived ? "checkmark" : "location.fill")
                    .foregroundStyle(context.state.isArrived ? .green : .blue)
            }
            .keylineTint(routeColor(context.state))
        }
    }

    @ViewBuilder
    private func routeBadge(_ state: JourneyActivityAttributes.ContentState) -> some View {
        if let shortName = state.routeShortName {
            Text(shortName)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .frame(minWidth: 25, minHeight: 25)
                .background(routeColor(state), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Image(systemName: state.isArrived ? "checkmark.circle.fill" : "figure.walk")
                .foregroundStyle(state.isArrived ? .green : .blue)
        }
    }

    private func routeColor(_ state: JourneyActivityAttributes.ContentState) -> Color {
        Color(activityHex: state.routeColorHex, fallback: .blue)
    }
}

private extension Color {
    init(activityHex: String?, fallback: Color) {
        guard let activityHex else {
            self = fallback
            return
        }
        let value = activityHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else {
            self = fallback
            return
        }
        self = Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
