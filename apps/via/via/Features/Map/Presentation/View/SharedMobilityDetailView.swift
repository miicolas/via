import SwiftUI

/// The sheet for an individual vehicle.
///
/// A dock is not one of its cases: `BikeStationDetailView` already is the
/// screen for a Vélib' station, and this view used to be a second one — with
/// its own wording for the same missing inventory, and without the "Itinéraire"
/// action the other offers. `MapShellView` routes a station there instead, so
/// which layer delivered the dock no longer changes what the traveller can do
/// with it.
struct SharedMobilityDetailView: View {
    let vehicle: SharedMobilityVehicle
    let distanceMeters: Double?
    let isLargeScreen: Bool
    @Binding var detailDetent: PresentationDetent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var isCollapsed: Bool {
        detailDetent == .height(DetailSheetPresentation.collapsedHeight)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    identity

                    vehicleDetails(vehicle)
                    if let restriction = vehicle.restriction {
                        restrictionBanner(restriction.message(for: vehicle.provider))
                    }

                    source
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(vehicle.displayTypeName)
            .toolbarTitleDisplayMode(isCollapsed ? .inline : .inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !isCollapsed, actionURL != nil {
                    Button("Ouvrir \(vehicle.provider.displayName)", systemImage: "arrow.up.right") {
                        openOperator()
                    }
                    .primaryAction()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
            }
        }
        .detailSheetPresentation(isLargeScreen: isLargeScreen, selection: $detailDetent)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SharedMobilityProviderLogoView(provider: vehicle.provider, size: 26)

                Text(identityTitle)
                    .font(.headline)
                    .foregroundStyle(.tint)
            }

            Text(identityDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func vehicleDetails(_ vehicle: SharedMobilityVehicle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            detailRow("Type", value: vehicle.displayTypeName, systemImage: vehicle.systemImage)
            detailRow("Opérateur", value: vehicle.provider.displayName, systemImage: "building.2")
            detailRow("Disponibilité", value: vehicle.availability.displayName, systemImage: "checkmark.circle")
            detailRow("Distance", value: distanceText, systemImage: "location")
            detailRow("Batterie", value: batteryText(vehicle.batteryPercent), systemImage: "battery.75percent")
            detailRow("Autonomie", value: rangeText(vehicle.rangeMeters), systemImage: "bolt.horizontal")
        }
        .padding(6)
        .background(.quaternary.opacity(0.7), in: .rect(cornerRadius: 18))
    }

    private func detailRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }

    private func restrictionBanner(_ note: String) -> some View {
        Label(note, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: .rect(cornerRadius: 16))
            .accessibilityElement(children: .combine)
    }

    /// The feed's own deep link first, the operator's site when the app that
    /// link names is not installed.
    private var actionURL: URL? {
        vehicle.rentalURL ?? vehicle.operatorURL
    }

    private func openOperator() {
        guard let url = actionURL else { return }
        guard let rentalURL = vehicle.rentalURL, let fallbackURL = vehicle.operatorURL else {
            openURL(url)
            return
        }

        openURL(rentalURL) { accepted in
            if !accepted {
                openURL(fallbackURL)
            }
        }
    }

    private var source: some View {
        Group {
            if let date = vehicle.lastReportedAt {
                Text("Actualisé \(RelativeTimeFormatting.short(date))")
            } else {
                Text("Actualisation non disponible")
            }
        }
        .font(.footnote)
        .foregroundStyle(.tertiary)
    }

    private var identityTitle: String {
        "\(vehicle.mode.displayName) \(vehicle.provider.displayName)"
    }

    private var identityDescription: String {
        "Véhicule individuel · Île-de-France"
    }

    private var distanceText: String {
        guard let distanceMeters else { return "Non disponible" }
        return DistanceFormatting.text(meters: distanceMeters)
    }

    private func batteryText(_ value: Double?) -> String {
        guard let value else { return "Non disponible" }
        return "\(Int(value.rounded())) %"
    }

    private func rangeText(_ value: Int?) -> String {
        guard let value else { return "Non disponible" }
        return DistanceFormatting.text(meters: Double(value))
    }

}
