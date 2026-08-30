import ActivityKit
import SwiftUI
import WidgetKit

struct MeetupActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeetupActivityAttributes.self) { context in
            MeetupActivityLockScreenView(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.expectedArrivalAt, style: .time)
                        .font(.caption.monospacedDigit())
                        .accessibilityLabel("Arrivée prévue")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.attributes.destinationName)
                            .font(.headline)
                        if let person = context.state.joinPersonName,
                           let station = context.state.joinStationName {
                            Text("\(person) · \(station)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(context.state.groupSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Rendez-vous en cours")
            } compactTrailing: {
                if let departure = context.state.nextDepartureAt,
                   context.state.groupState != .arrived,
                   context.state.groupState != .ended {
                    Text(timerInterval: Date.now...departure, countsDown: true)
                        .font(.caption2.monospacedDigit())
                } else {
                    Text(context.state.expectedArrivalAt, style: .time)
                        .font(.caption2.monospacedDigit())
                }
            } minimal: {
                Image(systemName: context.state.groupState == .arrived
                    ? "checkmark"
                    : "person.2.fill")
                    .foregroundStyle(context.state.groupState == .arrived ? .green : .blue)
                    .accessibilityLabel(context.state.groupSummary)
            }
            .keylineTint(.blue)
            .widgetURL(context.attributes.meetupURL)
        }
    }
}
