import SwiftUI

/// Compact departures preview for one nearby station; tapping opens the full
/// station sheet.
struct NearbyStationCard: View {
    let station: StationMapItem
    let departures: DeparturesViewModel
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(station.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if !station.routes.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(station.routes.prefix(5)) { route in
                                TransitRouteBadgeView(route: route, size: 20)
                            }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                departuresContent
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                .quaternary.opacity(0.45),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Départs de \(station.name)")
    }

    @ViewBuilder
    private var departuresContent: some View {
        switch departures.state {
        case .idle, .loading(previous: nil):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Prochains départs…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        case .loaded(let board), .loading(previous: .some(let board)), .failed(_, previous: .some(let board)):
            let snapshots = departureDirectionSnapshots(groups: board.groups, now: .now).prefix(3)
            if snapshots.isEmpty {
                Text("Aucun départ imminent.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshots)) { snapshot in
                        DepartureDirectionRow(
                            destination: snapshot.destination,
                            minutes: snapshot.minutes,
                            source: board.source
                        )
                    }
                }
            }
        case .failed(_, previous: nil):
            Label("Départs indisponibles", systemImage: "wifi.exclamationmark")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
        }
    }
}
