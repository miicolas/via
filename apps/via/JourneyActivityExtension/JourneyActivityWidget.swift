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
                Text(context.state.arrivalAt, style: .time)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                if context.isStale || context.state.isOffline {
                    Image(systemName: context.isStale ? "pause.circle.fill" : "wifi.slash")
                        .foregroundStyle(.orange)
                        .accessibilityLabel(
                            context.isStale ? "Mise à jour suspendue" : "Hors connexion"
                        )
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
