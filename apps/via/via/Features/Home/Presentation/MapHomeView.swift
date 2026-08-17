import SwiftUI

/// Idle home of the planner sheet: shortcut chips, nearby departures, then
/// recents. Replaces the old redundant "Raccourcis"/"Récents" pair fed by the
/// same list.
struct MapHomeView: View {
    let home: SavedPlace?
    let work: SavedPlace?
    let favoritePlaces: [SavedPlace]
    let favoriteStations: [FavoriteStation]
    let recentSearches: [RecentSearch]
    let location: LocationState
    let nearby: NearbyStationsViewModel
    let onSelectPlace: (SavedPlace) -> Void
    let onSelectFavoriteStation: (FavoriteStation) -> Void
    let onAddPlace: (SavedPlace.Role) -> Void
    let onRemovePlace: (SavedPlace) -> Void
    let onRemoveFavoriteStation: (FavoriteStation) -> Void
    let onSelectRecent: (RecentSearch) -> Void
    let onRemoveRecent: (RecentSearch) -> Void
    let onOpenStation: (StationMapItem) -> Void

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HomeShortcutChipsView(
                    home: home,
                    work: work,
                    favoritePlaces: favoritePlaces,
                    favoriteStations: favoriteStations,
                    onSelectPlace: onSelectPlace,
                    onSelectFavoriteStation: onSelectFavoriteStation,
                    onAddPlace: onAddPlace,
                    onRemovePlace: onRemovePlace,
                    onRemoveFavoriteStation: onRemoveFavoriteStation
                )
                .padding(.top, 10)
                .padding(.bottom, 16)

                NearbyStationsSection(
                    viewModel: nearby,
                    onOpenStation: onOpenStation
                )

                if recentSearches.isEmpty {
                    ViaAIOnboardingCard()
                } else {
                    Divider()

                    RecentSearchesSection(
                        recentSearches: recentSearches,
                        onSelect: onSelectRecent,
                        onRemove: onRemoveRecent
                    )
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .swipeActionsContainerIfAvailable()
        .onAppear {
            // Deliberately never stopped on disappear: the sheet flips to the
            // search or station screens and back constantly, and each restart
            // would refetch boards that were fresh seconds ago. Polling is
            // gated by scene activity instead.
            nearby.start()
            nearby.update(location: location, favorites: favoriteStations)
        }
        .onChange(of: location) { _, newLocation in
            nearby.update(location: newLocation, favorites: favoriteStations)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            nearby.setSceneActive(phase == .active)
        }
    }
}
