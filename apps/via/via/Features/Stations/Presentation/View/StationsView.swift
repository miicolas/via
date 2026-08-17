import SwiftUI

/// Temporary fixture rows until the Stations tab is wired to the network repositories.
struct StationPlaceholder: Identifiable {
    var id: String = UUID().uuidString
    var symbol: String
    var name: String
    var detail: String
    var distance: String

    static let data: [Self] = [
        .init(symbol: "tram.fill", name: "Châtelet", detail: "Métro 1 · 4 · 7 · 11 · 14", distance: "250 m"),
        .init(symbol: "tram.fill", name: "Hôtel de Ville", detail: "Métro 1 · 11", distance: "400 m"),
        .init(symbol: "train.side.front.car", name: "Gare de Lyon", detail: "RER A · D · Métro 1 · 14", distance: "1,8 km")
    ]
}

struct StationsView: View {
    @Binding var isLargeScreen: Bool
    @Binding var selectedStation: StationPlaceholder?
    @Binding var detailDetent: PresentationDetent

    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress

    var body: some View {
        NavigationStack {
            List {
                ForEach(StationPlaceholder.data) { station in
                    Button {
                        detailDetent = isLargeScreen ? .fraction(0.97) : .large
                        selectedStation = station
                    } label: {
                        StationRowLabel(station: station)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(StationPlaceholder.data.first?.id == station.id ? .hidden : .visible, edges: .top)
                    .listRowSeparatorTint(Color.gray.opacity(0.12))
                }
            }
            .listStyle(.plain)
            .navigationTitle("Stations")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
        .opacity(tabVisibilityProgress)
        .sheet(item: $selectedStation) { station in
            StationDetailView(
                station: station,
                isLargeScreen: isLargeScreen,
                detailDetent: $detailDetent
            )
        }
    }
}

private struct StationRowLabel: View {
    var station: StationPlaceholder

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: station.symbol)
                .font(.title3)
                .frame(width: 50, height: 50)
                .background {
                    Circle()
                        .fill(.windowBackground)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)

                Text(station.detail)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Spacer(minLength: 0)

            Text(station.distance)
                .font(.callout)
                .foregroundStyle(.gray)
        }
    }
}
