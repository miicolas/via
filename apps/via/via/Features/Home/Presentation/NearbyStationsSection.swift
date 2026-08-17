import SwiftUI

/// "À proximité" block of the home sheet: the closest stations with their
/// next departures, or the favorite stations when location is unavailable.
struct NearbyStationsSection: View {
    let viewModel: NearbyStationsViewModel
    let onOpenStation: (StationMapItem) -> Void

    var body: some View {
        if !viewModel.entries.isEmpty || viewModel.isLoading {
            VStack(alignment: .leading, spacing: 10) {
                ViaSectionHeader(viewModel.isUsingFavoritesFallback ? "Favoris" : "À proximité")

                if viewModel.entries.isEmpty {
                    NearbyStationsPlaceholder()
                } else {
                    GlassEffectContainer {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.entries) { entry in
                                NearbyStationCard(
                                    station: entry.station,
                                    departures: entry.departures
                                ) {
                                    onOpenStation(entry.station)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
    }
}

/// Skeleton card shown while the closest stations are being resolved.
private struct NearbyStationsPlaceholder: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Recherche des gares proches…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .viaGlassCard()
    }
}
