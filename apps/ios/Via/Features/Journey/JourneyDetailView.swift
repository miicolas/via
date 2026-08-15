import SwiftUI

struct JourneyDetailView: View {
    let journey: Journey
    let destination: JourneyDestination
    let onBack: () -> Void
    let onCancel: () -> Void
    let onOpenMaps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ViaButton(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retour aux itinéraires")

                VStack(alignment: .leading, spacing: 3) {
                    Text("Détail du trajet")
                        .font(.headline)
                        .foregroundStyle(ViaTheme.ink)
                    Text("Vers \(destination.name)")
                        .font(.caption)
                        .foregroundStyle(ViaTheme.muted)
                }
                Spacer()
                ViaButton(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer le trajet")
            }

            HStack(alignment: .firstTextBaseline) {
                Text("\(journeyMinutes(journey.durationSeconds)) min")
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(ViaTheme.ink)
                Text("· arrivée \(journeyTimeLabel(journey.arrivalAt) ?? "—")")
                    .font(.subheadline)
                    .foregroundStyle(ViaTheme.body)
                Spacer()
            }

            ViaButton(
                "Ouvrir dans Plans",
                systemImage: "arrow.triangle.turn.up.right.diamond",
                action: onOpenMaps
            )
            .accessibilityIdentifier("via.openJourneyInMaps")

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(journey.sections.enumerated()), id: \.offset) { index, section in
                    JourneySectionRow(section: section, isLast: index == journey.sections.count - 1)
                }
            }
        }
        .accessibilityIdentifier("via.journeyDetail.\(journey.id)")
    }
}
