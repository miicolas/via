import SwiftUI

/// The waiting time, worded once for the whole app: a capsule with the minutes
/// left, and — only when the feed is live — the glyph that says so.
///
/// Nothing marks a scheduled time. Via names the exception, never the ordinary
/// case: a clock badge on every timetable entry says "this is a departure",
/// which the traveller already knew, and drains the live badge of its meaning.
///
/// Past an hour the countdown stops being useful and the clock time takes over.
struct DepartureCountdownView: View {
    /// How loud the capsule is: the station board leads with it, a journey card
    /// carries it beside other facts.
    enum Prominence {
        case board
        case inline
    }

    let departureAt: Date
    let isLive: Bool
    var role: DepartureTimeColorRole = .neutral
    var prominence: Prominence = .board

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            capsule(now: context.date)
                .transaction { transaction in
                    if reduceMotion {
                        transaction.animation = nil
                    }
                }
        }
    }

    /// "Dans 4 minutes, à 11:04" — the same sentence wherever the capsule sits,
    /// so a caller only has to append what is local to its screen.
    static func spokenWait(until date: Date, now: Date = .now) -> String {
        let minutes = DepartureTimingMath.minutesUntil(date, now: now)
        let unit = minutes == 1 ? "minute" : "minutes"
        return "Dans \(minutes) \(unit), à \(timeText(date))"
    }

    private func capsule(now: Date) -> some View {
        let minutes = DepartureTimingMath.minutesUntil(departureAt, now: now)

        return HStack(alignment: .firstTextBaseline, spacing: spacing) {
            if isLive {
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(role.color)
                    .accessibilityHidden(true)
            }

            if minutes < 60 {
                Text("\(minutes)")
                    .font(numberFont)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(countsDown: true))

                Text("MIN")
                    .font(unitFont)
                    .foregroundStyle(.secondary)
                    .tracking(0.3)
            } else {
                Text(Self.timeText(departureAt))
                    .font(timeFont)
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text("départ")
                    .font(unitFont)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(role.color.opacity(0.10), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spokenWait(until: departureAt, now: now))
    }

    private static func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private var spacing: CGFloat {
        switch prominence {
        case .board: 5
        case .inline: 4
        }
    }

    private var glyphSize: CGFloat {
        switch prominence {
        case .board: 14
        case .inline: 11
        }
    }

    private var numberFont: Font {
        switch prominence {
        case .board: .system(.title2, design: .rounded).weight(.bold)
        case .inline: .system(.subheadline, design: .rounded).weight(.bold)
        }
    }

    private var unitFont: Font {
        switch prominence {
        case .board: .caption.weight(.semibold)
        case .inline: .caption2.weight(.semibold)
        }
    }

    private var timeFont: Font {
        switch prominence {
        case .board: .headline.weight(.semibold)
        case .inline: .subheadline.weight(.semibold)
        }
    }

    private var horizontalPadding: CGFloat {
        switch prominence {
        case .board: 9
        case .inline: 7
        }
    }

    private var verticalPadding: CGFloat {
        switch prominence {
        case .board: 5
        case .inline: 3
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        DepartureCountdownView(
            departureAt: .now.addingTimeInterval(240),
            isLive: true,
            role: .live
        )
        DepartureCountdownView(
            departureAt: .now.addingTimeInterval(900),
            isLive: false,
            role: .neutral
        )
        DepartureCountdownView(
            departureAt: .now.addingTimeInterval(240),
            isLive: true,
            role: .critical,
            prominence: .inline
        )
        DepartureCountdownView(
            departureAt: .now.addingTimeInterval(5_400),
            isLive: false,
            role: .neutral,
            prominence: .inline
        )
    }
    .padding()
}
