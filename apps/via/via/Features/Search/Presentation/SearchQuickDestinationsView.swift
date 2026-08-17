import SwiftUI

struct SearchQuickDestinationsView: View {
    let recent: [RecentSearch]
    let onSelect: (RecentSearch) -> Void

    private var quickDestinations: [RecentSearch] {
        Array(recent.prefix(3))
    }

    var body: some View {
        if !quickDestinations.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ViaSectionHeader("Raccourcis")

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(quickDestinations) { recent in
                            SearchQuickDestinationCard(recent: recent) {
                                onSelect(recent)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }
            .padding(.vertical, 10)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    SearchQuickDestinationsView(
        recent: [
            RecentSearch(
                id: "address:home",
                kind: .address,
                name: "Rue de Rivoli",
                context: "Paris",
                coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
                savedAt: .now
            ),
            RecentSearch(
                id: "station:la-defense",
                kind: .station,
                name: "La Défense",
                context: nil,
                coordinate: GeoCoordinate(latitude: 48.892, longitude: 2.236),
                savedAt: .now
            )
        ],
        onSelect: { _ in }
    )
    .padding()
}
