import SwiftUI

/// The "À venir" block: planned closures over the next seven days, one
/// section per day, each line tappable towards its detail.
struct UpcomingClosuresSection: View {
    let days: [(day: Date, lines: [LineStatus])]

    var body: some View {
        ForEach(days, id: \.day) { entry in
            Section("À venir · \(entry.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))") {
                ForEach(entry.lines) { status in
                    NavigationLink(value: status) {
                        HStack(spacing: 14) {
                            LineBadgeView(route: status.route, size: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(status.upcoming?.title ?? "Fermeture prévue")
                                    .font(.subheadline)
                                    .lineLimit(2)
                                if let beginsAt = status.upcoming?.beginsAt {
                                    Text("À partir de \(beginsAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        List {
            UpcomingClosuresSection(days: [
                (
                    day: Calendar.current.startOfDay(for: .now),
                    lines: PreviewLineStatusRepository.defaultBoard.lines.filter { $0.upcoming != nil }
                )
            ])
        }
    }
}
