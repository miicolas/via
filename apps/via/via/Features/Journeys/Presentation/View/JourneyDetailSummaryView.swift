import SwiftUI

/// The route card under the duration. It deliberately shows only facts the
/// journey model owns; fares and ticket products are never invented locally.
struct JourneyDetailSummaryView: View {
    let journey: Journey
    let source: JourneyResult.Source?
    var canEditTimes = true
    let onEditTime: (JourneyDatetimeRepresents) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if canEditTimes {
                Label("Choisir l’heure de départ ou d’arrivée", systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }

            VStack(spacing: 0) {
                scheduleRow(
                    name: originName,
                    label: "Départ",
                    value: journey.departureAt,
                    endpoint: .departure
                )

                Divider()
                    .padding(.leading, 18)

                scheduleRow(
                    name: destinationName,
                    label: "Arrivée",
                    value: journey.arrivalAt,
                    endpoint: .arrival
                )
            }
            .background(Color.secondary.opacity(0.11), in: .rect(cornerRadius: 22))

            Label(journey.qualifier.displayName, systemImage: journey.qualifier.systemImage)
                .font(.headline)
                .foregroundStyle(journey.qualifier.color)
                .padding(.horizontal, 18)
                .frame(minHeight: 48)
                .background(journey.qualifier.color.opacity(0.15), in: .capsule)
        }
    }

    private func scheduleRow(
        name: String,
        label: LocalizedStringKey,
        value: Date,
        endpoint: JourneyDatetimeRepresents
    ) -> some View {
        Button {
            onEditTime(endpoint)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(timingTint)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 7) {
                    Text(JourneyFormatting.time(value))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText())

                    Image(systemName: "slider.vertical.3")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(timingTint)
                .padding(.horizontal, 12)
                .frame(minWidth: 98, minHeight: 44, alignment: .trailing)
                .background(timingTint.opacity(0.12), in: .capsule)
                .contentShape(.rect)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canEditTimes)
        .accessibilityLabel(endpoint.accessibilityEditLabel)
        .accessibilityValue(JourneyFormatting.time(value))
        .accessibilityHint("Ouvre le sélecteur d’horaire")
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var originName: String {
        journey.sections.first?.from.name ?? "Départ"
    }

    private var destinationName: String {
        journey.sections.last?.to.name ?? "Destination"
    }

    private var timingTint: Color {
        .accentColor
    }

}

private extension JourneyDatetimeRepresents {
    var accessibilityEditLabel: String {
        switch self {
        case .departure: "Modifier l’heure de départ"
        case .arrival: "Modifier l’heure d’arrivée"
        }
    }
}
