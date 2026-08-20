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
                    if context.isStale {
                        Label("Mise à jour suspendue", systemImage: "pause.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else if context.state.isOffline {
                        Label("Hors connexion", systemImage: "wifi.slash")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else {
                        Text(context.state.phaseTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(context.state.instructionTitle)
                            .font(.headline)
                            .lineLimit(2)
                        if let detail = context.state.instructionDetail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if !context.state.isArrived {
                            JourneyActivityProgressBar(fraction: context.state.progressFraction)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                if context.isStale || context.state.isOffline {
                    Image(systemName: context.isStale ? "pause.circle.fill" : "wifi.slash")
                        .foregroundStyle(.orange)
                        .accessibilityLabel(
                            context.isStale ? "Mise à jour suspendue" : "Hors connexion"
                        )
                } else {
                    routeBadge(context.state)
                }
            } compactTrailing: {
                if let stopsRemaining = context.state.stopsRemaining,
                   !context.state.isArrived,
                   stopsRemaining > 0 {
                    // A bare count would read as a time; the arrow says what it
                    // counts down to.
                    Label("\(stopsRemaining)", systemImage: "arrow.down.right")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .labelStyle(.titleAndIcon)
                        .accessibilityLabel(
                            stopsRemaining == 1
                                ? "Descendre au prochain arrêt"
                                : "Descendre dans \(stopsRemaining) arrêts"
                        )
                } else if context.state.stopsRemaining == 0, !context.state.isArrived {
                    Image(systemName: "arrow.down.right.circle.fill")
                        .accessibilityLabel("Descendre maintenant")
                } else {
                    Text(context.state.arrivalAt, style: .time)
                        .font(.caption2.monospacedDigit())
                }
            } minimal: {
                if context.isStale || context.state.isOffline {
                    Image(systemName: context.isStale ? "pause.circle.fill" : "wifi.slash")
                        .foregroundStyle(.orange)
                        .accessibilityLabel(
                            context.isStale ? "Mise à jour suspendue" : "Hors connexion"
                        )
                } else if let line = context.state.line,
                          !context.state.isArrived,
                          line.shortName.count <= 2 {
                    // The minimal slot is a circle: only a one or two character
                    // line name fits, tinted so the line reads without a badge.
                    Text(line.shortName)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color(activityHex: line.colorHex, fallback: .blue))
                        .accessibilityLabel("Ligne \(line.shortName)")
                } else {
                    Image(systemName: context.state.isArrived ? "checkmark" : "location.fill")
                        .foregroundStyle(context.state.isArrived ? .green : .blue)
                        .accessibilityLabel(
                            context.state.isArrived ? "Vous êtes arrivé" : "Trajet actif"
                        )
                }
            }
            .keylineTint(routeColor(context.state))
            .widgetURL(URL(string: "via://journey/\(context.attributes.journeyID)"))
        }
    }

    /// The line badge, or a phase symbol when the current leg has no line.
    @ViewBuilder
    private func routeBadge(_ state: JourneyActivityAttributes.ContentState) -> some View {
        if let line = state.line, !state.isArrived {
            JourneyActivityLineBadgeView(line: line, size: 25)
        } else {
            Image(systemName: state.isArrived ? "checkmark.circle.fill" : "figure.walk")
                .foregroundStyle(state.isArrived ? .green : .blue)
        }
    }

    private func routeColor(_ state: JourneyActivityAttributes.ContentState) -> Color {
        Color(activityHex: state.line?.colorHex, fallback: .blue)
    }
}
