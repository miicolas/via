import SwiftUI

/// One line of the nearby list: the name, how far it is, what runs there, and
/// the facility that made it match.
///
/// Deliberately lighter than `StationRowLabel`: a departure board is one
/// request per station, so the leading station keeps it and the rest of the
/// list says where it is and why it is here. The criterion marks are silent
/// glyphs rather than the header's `InfoBadgeButton` — a popover inside a row
/// that is itself a button would swallow the tap that opens the station.
struct NearbyStationRow: View {
    let station: NearbyStation
    let filter: StationMapFilter
    let action: () -> Void

    private static let maximumVisibleRoutes = 3

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                glyph

                VStack(alignment: .leading, spacing: 6) {
                    Text(station.item.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    detail
                }

                Spacer(minLength: 8)

                Text(DistanceFormatting.text(meters: station.distanceMeters))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(DistanceFormatting.text(meters: station.distanceMeters))
        .accessibilityHint("Affiche cette station sur la carte")
    }

    @ViewBuilder
    private var glyph: some View {
        if station.item.bikeStation != nil {
            Image(systemName: "bicycle")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32)
        } else if let mode = station.item.modes.first {
            TransitModeIconView(mode: mode, size: 24)
                .frame(width: 32)
        } else {
            Image(systemName: "mappin.and.ellipse")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let bike = station.item.bikeStation {
            bikeInventory(bike)
        } else {
            HStack(spacing: 6) {
                ForEach(station.item.routes.prefix(Self.maximumVisibleRoutes)) { route in
                    LineBadgeView(route: route, size: 20)
                }

                if station.item.routes.count > Self.maximumVisibleRoutes {
                    LineBadgeOverflowView(
                        count: station.item.routes.count - Self.maximumVisibleRoutes,
                        size: 20
                    )
                }

                criterionMarks
            }
        }
    }

    private func bikeInventory(_ bike: BikeStation) -> some View {
        Group {
            if let availability = bike.availability {
                HStack(spacing: 8) {
                    Label("\(availability.totalBikes)", systemImage: "bicycle")
                    Label("\(availability.docks)", systemImage: "parkingsign")
                }
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(availability.isOperational ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
            } else {
                Text("Disponibilité inconnue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Only the facilities the traveller actually asked for. Showing every
    /// fact a station holds would make the row say nothing in particular.
    @ViewBuilder
    private var criterionMarks: some View {
        ForEach(matchedFacilities, id: \.self) { criterion in
            Image(systemName: criterion.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var matchedFacilities: [StationMapFilterCriterion] {
        StationMapFilterCriterion.facilities.filter { criterion in
            guard filter.contains(criterion) else { return false }
            switch criterion {
            case .accessibility: return station.item.accessibility != nil
            case .elevators: return station.item.hasElevators
            case .toilets: return station.item.toilets != nil
            case .bikeStations, .mode: return false
            }
        }
    }

    private var accessibilityLabel: String {
        if let bike = station.item.bikeStation {
            let detail = bike.availability?.accessibilityDetail ?? "disponibilité inconnue"
            return "Station Vélib \(station.item.name), \(detail)"
        }

        var parts = ["Station \(station.item.name)"]
        if !station.item.routes.isEmpty {
            parts.append("lignes \(station.item.routes.map(\.shortName).joined(separator: ", "))")
        }
        parts.append(contentsOf: matchedFacilities.map(\.title))
        return parts.joined(separator: ", ")
    }
}
