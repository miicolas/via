import SwiftUI

struct DepartureLineRow: View {
    let route: RouteBadge
    let departure: StationDeparture?
    let source: DepartureBoard.Source

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedDate = Date.now

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            LineBadgeView(route: route, size: 36)
                .frame(minWidth: 36, alignment: .leading)

            if let departure {
                Text(departure.destination)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TimelineView(.periodic(from: .now, by: 30)) { context in
                    waitingTime(for: departure.departureAt, now: displayedDate)
                        .onChange(of: context.date) { _, newDate in
                            if reduceMotion {
                                displayedDate = newDate
                            } else {
                                withAnimation(.snappy) {
                                    displayedDate = newDate
                                }
                            }
                        }
                }
            } else {
                Text(source == .unavailable ? "Horaires indisponibles" : "Aucun passage à venir")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }

    private var statusIcon: some View {
        Group {
            if source == .realtime && !reduceMotion {
                Image(systemName: statusSystemImage)
                    .symbolEffect(.variableColor)
            } else {
                Image(systemName: statusSystemImage)
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(statusColor)
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }

    private func waitingTime(for date: Date, now: Date) -> some View {
        let time = waitingTimeParts(for: date, now: now)

        return HStack(spacing: 8) {
            statusIcon

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(time.value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(countsDown: true))

                Text(time.unit)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.10), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(time.value) \(time.unit), \(statusText)")
    }

    private func waitingTimeParts(for date: Date, now: Date) -> (value: String, unit: String) {
        let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
        if minutes < 60 {
            return ("\(minutes)", "MIN")
        }

        return (date.formatted(date: .omitted, time: .shortened), "DÉPART")
    }

    private var statusText: String {
        switch source {
        case .realtime:
            "Temps réel"
        case .theoretical:
            "Théorique"
        case .unavailable:
            "Indisponible"
        }
    }

    private var statusSystemImage: String {
        switch source {
        case .realtime:
            "dot.radiowaves.up.forward"
        case .theoretical:
            "clock"
        case .unavailable:
            "clock.badge.exclamationmark"
        }
    }

    private var statusColor: Color {
        switch source {
        case .realtime:
            .green
        case .theoretical:
            .orange
        case .unavailable:
            .secondary
        }
    }
}
