import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult
    let accessibilityHint: String
    let action: () -> Void
    let onDelete: (() -> Void)?

    init(
        result: SearchResult,
        accessibilityHint: String = "Sélectionne cette destination",
        action: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
    ) {
        self.result = result
        self.accessibilityHint = accessibilityHint
        self.action = action
        self.onDelete = onDelete
    }

    var body: some View {
        if let onDelete {
            rowContent
                .contextMenu {
                    Button("Supprimer", systemImage: "trash", role: .destructive, action: onDelete)
                }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                resultIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    resultDetails
                }

                Spacer(minLength: 4)
            }
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    @ViewBuilder
    private var resultIcon: some View {
        switch result {
        case .station(let station):
            Image(systemName: station.routes.first?.mode.chipSystemImage ?? "tram.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32)

        case .address(let address):
            Image(systemName: address.isBikeStation ? "bicycle" : "mappin.and.ellipse")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32)
        }
    }

    @ViewBuilder
    private var resultDetails: some View {
        switch result {
        case .station(let station):
            VStack(alignment: .leading, spacing: 6) {
                if station.routes.isEmpty {
                    Text("Station")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 6) {
                        ForEach(station.routes.prefix(3)) { route in
                            LineBadgeView(route: route, size: 20)
                        }
                    }
                }
            }

        case .address(let address):
            Text(addressDetail(address))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var accessibilityLabel: String {
        switch result {
        case .station(let station):
            let routes = station.routes.map(\.shortName).joined(separator: ", ")
            let base = routes.isEmpty ? "Station \(station.name)" : "Station \(station.name), lignes \(routes)"
            return base
        case .address(let address):
            if address.isBikeStation {
                let detail = address.bikeStation?.accessibilityDetail ?? "disponibilité inconnue"
                return "Station Vélib \(address.name), \(detail)"
            }
            return address.context.isEmpty
                ? "Adresse \(address.name)"
                : "Adresse \(address.name), \(address.context)"
        }
    }

    private func addressDetail(_ address: AddressSearchResult) -> String {
        guard let availability = address.bikeStation else { return address.subtitle }
        return "\(availability.totalBikes) vélo\(availability.totalBikes > 1 ? "s" : "") · \(availability.docks) bornette\(availability.docks > 1 ? "s" : "")"
    }
}

#Preview {
    SearchResultRow(result: .previewStation, action: {})
        .padding(.horizontal)
}
