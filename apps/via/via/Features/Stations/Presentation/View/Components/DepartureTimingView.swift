import SwiftUI

enum DepartureTimeColorRole: Equatable {
    case live
    case theoretical
    case attention
    case critical
    case neutral
}

func departureTimeColorRole(
    status: DepartureStatus?,
    source: DepartureBoard.Source
) -> DepartureTimeColorRole {
    switch status {
    case .cancelled, .delayed:
        .critical
    case .missed:
        .attention
    case .early:
        .live
    case .noReport:
        source == .realtime ? .live : .neutral
    default:
        switch source {
        case .realtime:
            .live
        case .theoretical:
            .theoretical
        case .unavailable:
            .neutral
        }
    }
}

enum DepartureTimingMath {
    static func minutesUntil(_ date: Date, now: Date) -> Int {
        let remainingSeconds = date.timeIntervalSince(now)
        guard remainingSeconds > 0 else { return 0 }
        return Int(ceil(remainingSeconds / 60))
    }

    static func roundedDelayMinutes(_ seconds: Int) -> Int {
        max(1, Int((Double(abs(seconds)) / 60).rounded()))
    }
}

struct DepartureTimingView: View {
    let departure: StationDeparture
    let source: DepartureBoard.Source

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch departure.status {
        case .cancelled:
            operationalStatusView(
                title: "Annulé",
                systemImage: "xmark.circle.fill",
                color: .red,
                accessibilityLabel: "\(departure.destination), passage annulé"
            )
        case .missed:
            operationalStatusView(
                title: "Non desservi",
                systemImage: "slash.circle.fill",
                color: .orange,
                accessibilityLabel: "\(departure.destination), arrêt non desservi"
            )
        case .delayed, .early:
            if let scheduledAt = departure.scheduledAt,
               let expectedAt = departure.departureAt {
                delayView(
                    for: departure,
                    scheduledAt: scheduledAt,
                    expectedAt: expectedAt
                )
            } else {
                countdownView(for: departure)
            }
        case .arrived, .departed:
            EmptyView()
        case .onTime, .noReport, .scheduled:
            countdownView(for: departure)
        }
    }

    @ViewBuilder
    private func countdownView(for departure: StationDeparture) -> some View {
        if let departureAt = departure.departureAt {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                waitingTime(for: departureAt, now: context.date)
                    .transaction { transaction in
                        if reduceMotion {
                            transaction.animation = nil
                        }
                    }
            }
        } else {
            operationalStatusView(
                title: "Horaire indisponible",
                systemImage: "clock.badge.exclamationmark",
                color: .secondary,
                accessibilityLabel: "\(departure.destination), horaire indisponible"
            )
        }
    }

    private func delayView(
        for departure: StationDeparture,
        scheduledAt: Date,
        expectedAt: Date
    ) -> some View {
        let rawDelay = departure.delaySeconds
            ?? Int(expectedAt.timeIntervalSince(scheduledAt).rounded())
        let delayMinutes = DepartureTimingMath.roundedDelayMinutes(rawDelay)
        let delayLabel = rawDelay >= 0 ? "+\(delayMinutes) min" : "−\(delayMinutes) min"
        let accent: Color = rawDelay >= 0 ? .red : .green
        let accessibilityDelay = rawDelay >= 0
            ? "retard de \(delayMinutes) \(delayMinutes == 1 ? "minute" : "minutes")"
            : "en avance de \(delayMinutes) \(delayMinutes == 1 ? "minute" : "minutes")"

        return VStack(alignment: .trailing, spacing: 1) {
            Text(timeText(scheduledAt))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .strikethrough()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(timeText(expectedAt))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(accent)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Image(systemName: rawDelay >= 0
                        ? "exclamationmark.circle.fill"
                        : "arrow.up.circle.fill")
                        .accessibilityHidden(true)

                    Text(delayLabel)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundStyle(accent)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(departure.destination), prévu à " +
                "\(timeText(scheduledAt)), estimé à \(timeText(expectedAt)), " +
                accessibilityDelay
        )
    }

    private func operationalStatusView(
        title: String,
        systemImage: String,
        color: Color,
        accessibilityLabel: String
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)

            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.10), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func waitingTime(for date: Date, now: Date) -> some View {
        let minutes = DepartureTimingMath.minutesUntil(date, now: now)
        let exactTime = timeText(date)

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                statusIcon

                if minutes < 60 {
                    Text("\(minutes)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(countsDown: true))

                    Text("MIN")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.3)
                } else {
                    Text(exactTime)
                        .font(.headline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Text("départ")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(statusColor.opacity(0.10), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Dans \(minutes) \(minutes == 1 ? "minute" : "minutes"), à \(exactTime), " +
                statusText
        )
    }

    private var statusIcon: some View {
        Image(systemName: source == .realtime
            ? "dot.radiowaves.up.forward"
            : "clock")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(statusColor)
            .frame(width: 17, height: 17)
            .accessibilityHidden(true)
    }

    private var statusText: String {
        switch departure.status {
        case .cancelled:
            "Annulé"
        case .missed:
            "Arrêt non desservi"
        case .early:
            "En avance"
        case .delayed:
            "En retard"
        case .noReport:
            "Horaire estimé en temps réel"
        case .arrived:
            "Arrivé"
        case .departed:
            "Parti"
        case .onTime, .scheduled:
            switch source {
            case .realtime:
                "Temps réel"
            case .theoretical:
                "Horaire théorique"
            case .unavailable:
                "Indisponible"
            }
        }
    }

    private var statusColor: Color {
        departureTimeColorRole(status: departure.status, source: source).color
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
