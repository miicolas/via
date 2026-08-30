import ActivityKit
import SwiftUI
import WidgetKit

struct JourneyActivityLockScreenView: View {
    let context: ActivityViewContext<JourneyActivityAttributes>

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leading

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    JourneyActivityStatusView(
                        state: context.state,
                        isStale: context.isStale
                    )

                    Spacer(minLength: 8)

                    JourneyActivityTimeSummary(state: context.state)
                }

                Text(context.state.instructionTitle)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)

                if let detail = context.state.instructionDetail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(context.state.stopProgress == nil ? 2 : 1)
                }

                if let stopProgress = context.state.stopProgress {
                    JourneyActivityStopProgressView(progress: stopProgress)
                }

                if context.state.stopProgress == nil,
                   let nextAction = context.state.nextAction {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

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
        .widgetURL(context.attributes.journeyURL)
    }

    /// The line is the fastest way to identify the current transit leg. A
    /// phase symbol takes its place for walking, arrival, and terminal states.
    @ViewBuilder
    private var leading: some View {
        if let line = context.state.line,
           context.state.presentationPhase != .arrived,
           context.state.presentationPhase != .ended {
            JourneyActivityLineBadgeView(line: line, size: 30)
        } else {
            Image(systemName: context.state.phaseSystemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(context.state.phaseTint)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
        }
    }
}

extension JourneyActivityAttributes.ContentState {
    /// Infers the phase for activities created before the semantic phase was
    /// added to the payload.
    var presentationPhase: JourneyActivityAttributes.Phase {
        if let phase { return phase }
        if isArrived { return .arrived }
        if phaseTitle == "Trajet en pause" { return .paused }
        if phaseTitle.hasPrefix("Départ") { return .scheduled }
        return .underway
    }

    var phaseSystemImage: String {
        switch presentationPhase {
        case .scheduled: "clock.fill"
        case .underway: "location.fill"
        case .paused: "pause.circle.fill"
        case .arrived: "checkmark.circle.fill"
        case .ended: "xmark.circle.fill"
        }
    }

    var phaseTint: Color {
        switch presentationPhase {
        case .scheduled, .underway: .blue
        case .paused: .orange
        case .arrived: .green
        case .ended: .secondary
        }
    }

    var countdownDate: Date? {
        switch presentationPhase {
        case .scheduled: departureAt ?? arrivalAt
        case .underway: arrivalAt
        case .paused, .arrived, .ended: nil
        }
    }

    var phaseStatusTitle: String {
        switch presentationPhase {
        case .scheduled: "Départ"
        case .underway: "En route"
        case .paused: "Trajet en pause"
        case .arrived: "Vous êtes arrivé"
        case .ended: phaseTitle
        }
    }

    /// What the status badge says. An alert condition speaks over the journey
    /// phase; `overridesPhase` is that same test, so the widget decides whether
    /// to show the badge from this ladder instead of re-listing its conditions.
    struct Status {
        let title: String
        let systemImage: String
        let tint: Color
        let overridesPhase: Bool
    }

    func status(isStale: Bool) -> Status {
        if isStale {
            return Status(
                title: "Mise à jour suspendue",
                systemImage: "pause.circle.fill",
                tint: .orange,
                overridesPhase: true
            )
        }
        if isOffline {
            return Status(
                title: "Hors connexion",
                systemImage: "wifi.slash",
                tint: .orange,
                overridesPhase: true
            )
        }
        if presentationPhase == .underway,
           let stopProgress,
           stopProgress.remainingStopCount <= 1 {
            return Status(
                title: stopProgress.remainingStopCount == 0
                    ? "Descendez maintenant"
                    : "Prochain arrêt",
                systemImage: "arrow.down.circle.fill",
                tint: .orange,
                overridesPhase: true
            )
        }
        return Status(
            title: phaseStatusTitle,
            systemImage: phaseSystemImage,
            tint: phaseTint,
            overridesPhase: false
        )
    }
}

struct JourneyActivityStatusView: View {
    let state: JourneyActivityAttributes.ContentState
    let isStale: Bool
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImage)
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)

            Text(status.title)
                .lineLimit(1)
        }
        .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
        .foregroundStyle(status.tint)
        .accessibilityElement(children: .combine)
    }

    private var status: JourneyActivityAttributes.ContentState.Status {
        state.status(isStale: isStale)
    }
}

struct JourneyActivityStatusIcon: View {
    let state: JourneyActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        Image(systemName: status.systemImage)
            .foregroundStyle(status.tint)
            .accessibilityLabel(status.title)
    }

    private var status: JourneyActivityAttributes.ContentState.Status {
        state.status(isStale: isStale)
    }
}

struct JourneyActivityCountdownView: View {
    let date: Date

    var body: some View {
        if date > Date() {
            Text(
                timerInterval: Date()...date,
                countsDown: true,
                showsHours: date.timeIntervalSinceNow >= 3_600
            )
        } else {
            Text("maintenant")
        }
    }
}

struct JourneyActivityTimeSummary: View {
    let state: JourneyActivityAttributes.ContentState
    var compact = false

    var body: some View {
        switch state.presentationPhase {
        case .scheduled:
            VStack(alignment: .trailing, spacing: 1) {
                Text("Départ")
                    .font(compact ? .caption2 : .caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let date = state.countdownDate {
                    JourneyActivityCountdownView(date: date)
                        .font(compact ? .caption2.monospacedDigit() : .subheadline.weight(.bold).monospacedDigit())
                }
            }
        case .underway, .paused:
            VStack(alignment: .trailing, spacing: 1) {
                Text("Arrivée")
                    .font(compact ? .caption2 : .caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(state.arrivalAt, style: .time)
                    .font(compact ? .caption2.monospacedDigit() : .subheadline.weight(.bold).monospacedDigit())
            }
        case .arrived, .ended:
            EmptyView()
        }
    }
}
