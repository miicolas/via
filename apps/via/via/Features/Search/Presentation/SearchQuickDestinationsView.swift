import SwiftUI

struct SearchQuickDestinationsView: View {
    let recent: [RecentSearch]
    let onSelect: (RecentSearch) -> Void
    /// The horizontal inset of the surrounding list; the carousel escapes it
    /// so cards scroll to the sheet edge instead of being chopped at the
    /// padded bounds, and `contentMargins` restores it at rest.
    var horizontalInset: CGFloat = 16

    private var quickDestinations: [RecentSearch] {
        Array(recent.prefix(3))
    }

    var body: some View {
        if !quickDestinations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ViaSectionHeader("Raccourcis")

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(quickDestinations) { recent in
                            SearchQuickDestinationCard(recent: recent) {
                                onSelect(recent)
                            }
                        }
                    }
                    .padding(.vertical, 1)
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .padding(.horizontal, -horizontalInset)
            }
            .padding(.top, 6)
            .padding(.bottom, 14)
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
