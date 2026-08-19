import SwiftUI

struct JourneyAlternativeCard: View {
    let alternative: ActiveJourneyAlternative
    let onAccept: () -> Void
    let onShowOthers: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Button(role: .close) {
                    onDismiss()
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button("Changer de trajet", action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)

                if !alternative.otherJourneys.isEmpty {
                    Button("Autres options", action: onShowOthers)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var summary: String {
        let arrival = JourneyFormatting.time(alternative.journey.arrivalAt)
        let currentArrival = JourneyFormatting.time(alternative.currentArrivalAt)
        let transferCount = alternative.journey.transferCount
        let transfers = transferCount == 0
            ? "direct"
            : transferCount == 1 ? "1 correspondance" : "\(transferCount) correspondances"
        if alternative.minutesSaved > 0 {
            let gain = alternative.minutesSaved == 1
                ? "1 min gagnée"
                : "\(alternative.minutesSaved) min gagnées"
            return "Actuel \(currentArrival) → nouveau \(arrival) · \(gain) · \(transfers)"
        }
        return "Actuel \(currentArrival) → nouveau \(arrival) · \(transfers)"
    }

    private var title: String {
        alternative.minutesSaved > 0
            ? "Un itinéraire plus rapide est disponible"
            : "Un nouvel itinéraire est disponible"
    }
}
