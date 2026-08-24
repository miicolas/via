import SwiftUI

struct BikeStationDetailView: View {
    let station: BikeStation
    let isLargeScreen: Bool
    @Binding var detailDetent: PresentationDetent
    let onPlanJourney: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if let availability = station.availability {
                        availabilityContent(availability)
                    } else {
                        EmptyStateView(.unavailable(
                            title: "Disponibilité inconnue",
                            message: "Vélib’ n’a pas fourni l’état en temps réel de cette station."
                        ))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(station.name)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Itinéraire", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                    onPlanJourney()
                    dismiss()
                }
                .primaryAction()
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .detailSheetPresentation(isLargeScreen: isLargeScreen, selection: $detailDetent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Station Vélib’", systemImage: "bicycle")
                .font(.headline)

            Text(station.stationCode.map { "Station \($0) · \(station.capacity) places" }
                ?? "\(station.capacity) places")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func availabilityContent(_ availability: BikeStationAvailability) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                metric(
                    availability.mechanicalBikes,
                    title: "Mécaniques",
                    systemImage: "bicycle"
                )
                metric(
                    availability.electricBikes,
                    title: "Électriques",
                    systemImage: "bolt.fill"
                )
                metric(
                    availability.docks,
                    title: "Bornettes",
                    systemImage: "parkingsign"
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(
                    availability.isRenting ? "Location disponible" : "Location indisponible",
                    systemImage: availability.isRenting ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                Label(
                    availability.isReturning ? "Retour disponible" : "Retour indisponible",
                    systemImage: availability.isReturning ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(availability.isOperational ? Color.secondary : Color.orange)

            if let lastReportedAt = availability.lastReportedAt {
                Text("Mis à jour \(RelativeTimeFormatting.short(lastReportedAt)) · Vélib’ Métropole")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Source : Vélib’ Métropole")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metric(_ value: Int, title: String, systemImage: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.tint)

            Text("\(value)")
                .font(.title2.weight(.bold))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.quaternary, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(title.lowercased())")
    }
}
