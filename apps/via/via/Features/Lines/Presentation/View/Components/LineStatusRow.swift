import SwiftUI

struct LineStatusRow: View {
    let status: LineStatus

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            LineBadgeView(route: status.route, size: 36)
                .frame(minWidth: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(statusText)
                        .font(.body.weight(.medium))
                        .foregroundStyle(status.condition == .normal ? .secondary : .primary)
                        .lineLimit(2)
                }

                if let upcoming = status.upcoming {
                    UpcomingClosureLabel(closure: upcoming)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LineConditionLabel(condition: status.condition, compact: true)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        status.summary ?? status.condition.title
    }
}

/// The "line runs now but closes soon" call-out — deliberately visible on the
/// row itself, not buried in a secondary section.
struct UpcomingClosureLabel: View {
    let closure: UpcomingClosure

    var body: some View {
        Label(text, systemImage: "clock.badge.exclamationmark")
            .font(.caption.weight(.medium))
            .foregroundStyle(.orange)
            .lineLimit(1)
    }

    private var text: String {
        let time = closure.beginsAt.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(closure.beginsAt) {
            return "Fermeture prévue à \(time)"
        }
        let day = closure.beginsAt.formatted(.dateTime.weekday(.wide).day())
        return "Fermeture prévue \(day) à \(time)"
    }
}

#Preview {
    List {
        ForEach(PreviewLineStatusRepository.defaultBoard.lines) { status in
            LineStatusRow(status: status)
        }
    }
}
