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
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    routeBadge(context.state, size: 24)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    JourneyActivityTimeSummary(state: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    JourneyActivityStatusView(
                        state: context.state,
                        isStale: context.isStale,
                        compact: true
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.instructionTitle)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)

                        if let detail = context.state.instructionDetail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let nextAction = context.state.nextAction {
                            Text("Ensuite · \(nextAction)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                if context.state.status(isStale: context.isStale).overridesPhase
                    || context.state.presentationPhase == .paused {
                    JourneyActivityStatusIcon(
                        state: context.state,
                        isStale: context.isStale
                    )
                } else {
                    routeBadge(context.state, size: 22)
                }
            } compactTrailing: {
                compactTrailing(for: context.state)
            } minimal: {
                minimalContent(for: context.state, isStale: context.isStale)
            }
            .keylineTint(routeColor(context.state))
            .widgetURL(context.attributes.journeyURL)
        }
    }

    @ViewBuilder
    private func compactTrailing(
        for state: JourneyActivityAttributes.ContentState
    ) -> some View {
        switch state.presentationPhase {
        case .scheduled:
            if let date = state.countdownDate {
                JourneyActivityCountdownView(date: date)
                    .font(.caption2.monospacedDigit())
                    .accessibilityLabel("Temps avant le départ")
            }
        case .underway:
            Text(state.arrivalAt, style: .time)
                .font(.caption2.monospacedDigit())
                .accessibilityLabel("Arrivée prévue à")
        case .paused:
            Text(state.arrivalAt, style: .time)
                .font(.caption2.monospacedDigit())
                .accessibilityLabel("Arrivée prévue à")
        case .arrived:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Vous êtes arrivé")
        case .ended:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
                .accessibilityLabel(state.phaseTitle)
        }
    }

    @ViewBuilder
    private func minimalContent(
        for state: JourneyActivityAttributes.ContentState,
        isStale: Bool
    ) -> some View {
        if state.status(isStale: isStale).overridesPhase || state.presentationPhase == .paused {
            JourneyActivityStatusIcon(state: state, isStale: isStale)
        } else if state.presentationPhase == .arrived {
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
                .accessibilityLabel("Vous êtes arrivé")
        } else if let line = state.line, line.shortName.count <= 2 {
            Text(line.shortName)
                .font(.caption2.weight(.heavy).monospacedDigit())
                .foregroundStyle(Color(activityHex: line.colorHex, fallback: .blue))
                .accessibilityLabel("Ligne \(line.shortName)")
        } else {
            Image(systemName: "location.fill")
                .foregroundStyle(.blue)
                .accessibilityLabel("Trajet actif")
        }
    }

    /// The line badge, or a phase symbol when the current step has no line.
    @ViewBuilder
    private func routeBadge(
        _ state: JourneyActivityAttributes.ContentState,
        size: CGFloat
    ) -> some View {
        if let line = state.line,
           state.presentationPhase != .arrived,
           state.presentationPhase != .ended {
            JourneyActivityLineBadgeView(line: line, size: size)
        } else {
            Image(systemName: state.phaseSystemImage)
                .foregroundStyle(state.phaseTint)
        }
    }

    private func routeColor(_ state: JourneyActivityAttributes.ContentState) -> Color {
        Color(activityHex: state.line?.colorHex, fallback: state.phaseTint)
    }
}
