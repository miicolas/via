import SwiftUI

/// The planned journey surfaced in the search list, above the recent
/// destinations: one tap opens its detail, deletion lives in the swipe and the
/// context menu like any other row of the list.
struct PlannedJourneyRow: View {
    let draft: PlannedJourneyDraft
    let action: () -> Void
    let onDelete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Button(action: action) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.destination.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(scheduleLabel(at: context.date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)
                }
                .padding(.vertical, 10)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Supprimer", systemImage: "trash", role: .destructive, action: onDelete)
            }
            .accessibilityLabel(
                "Trajet prévu vers \(draft.destination.name), \(scheduleLabel(at: context.date))"
            )
            .accessibilityHint("Ouvre le détail du trajet prévu")
        }
    }

    private func scheduleLabel(at date: Date) -> String {
        let departureAt = draft.journey.departureAt
        guard departureAt > date else {
            return "Départ \(JourneyFormatting.time(departureAt))"
        }
        return "Départ \(departureAt.formatted(.relative(presentation: .named))) · \(JourneyFormatting.time(departureAt))"
    }
}
