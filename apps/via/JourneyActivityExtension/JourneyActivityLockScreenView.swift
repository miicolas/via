import ActivityKit
import SwiftUI
import WidgetKit

struct JourneyActivityLockScreenView: View {
    let context: ActivityViewContext<JourneyActivityAttributes>

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            leading

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if context.isStale {
                        Label("Mise à jour suspendue", systemImage: "pause.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else if context.state.isOffline {
                        Label("Hors connexion", systemImage: "wifi.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else {
                        Text(context.state.phaseTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
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

                if !context.state.isArrived {
                    JourneyActivityProgressBar(fraction: context.state.progressFraction)
                        .padding(.top, 2)
                }

                if let nextAction = context.state.nextAction {
                    HStack(spacing: 5) {
                        if let nextLine = context.state.nextLine {
                            JourneyActivityLineBadgeView(line: nextLine, size: 18)
                        }
                        Text("Ensuite · \(nextAction)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .widgetURL(journeyURL)
    }

    /// The line badge outranks the phase symbol: on a locked screen the number
    /// is what identifies the leg at a glance.
    @ViewBuilder
    private var leading: some View {
        if let line = context.state.line, !context.state.isArrived {
            JourneyActivityLineBadgeView(line: line, size: 28)
        } else {
            Image(systemName: context.state.isArrived ? "checkmark.circle.fill" : "location.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(context.state.isArrived ? .green : .blue)
                .accessibilityHidden(true)
        }
    }

    private var journeyURL: URL? {
        URL(string: "via://journey/\(context.attributes.journeyID)")
    }
}

/// Mirrors the in-app progress bar, so the lock screen shows the same amount of
/// journey done as the timeline rail does.
struct JourneyActivityProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(.white.opacity(0.22))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: proxy.size.width * min(max(0, fraction), 1))
                }
                .clipShape(Capsule())
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("Progression du trajet")
        .accessibilityValue("\(Int((min(max(0, fraction), 1) * 100).rounded())) pour cent")
    }
}
