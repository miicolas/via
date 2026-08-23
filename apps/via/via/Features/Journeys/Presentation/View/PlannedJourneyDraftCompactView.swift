import SwiftUI

/// The planned journey in the collapsed map sheet: one tap opens its detail,
/// while the prominent location glyph starts it immediately.
struct PlannedJourneyDraftCompactView: View {
    let draft: PlannedJourneyDraft
    let onOpen: () -> Void
    let onLaunch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 38, height: 38)
                        .background(Color.accentColor.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trajet prévu")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(draft.destination.name)
                            .font(.headline)
                            .lineLimit(1)

                        Text(scheduleLabel)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Trajet prévu vers \(draft.destination.name), \(scheduleLabel)"
            )
            .accessibilityHint("Ouvre le détail du trajet prévu")

            Button("Lancer", systemImage: "location.fill", action: onLaunch)
                .labelStyle(.iconOnly)
                .iconAction(isProminent: true)
                .accessibilityHint("Lance le guidage et supprime le brouillon")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }

    private var scheduleLabel: String {
        "Départ \(draft.journey.departureAt.formatted(.relative(presentation: .named))) · \(JourneyFormatting.time(draft.journey.departureAt))"
    }
}
