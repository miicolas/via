import SwiftUI

/// Apple Maps-style shortcut row: home, work, saved favorites, then an add
/// chip. Empty home/work chips stay visible so saving a place is one tap away.
struct HomeShortcutChipsView: View {
    let home: SavedPlace?
    let work: SavedPlace?
    let favoritePlaces: [SavedPlace]
    let favoriteStations: [FavoriteStation]
    let onSelectPlace: (SavedPlace) -> Void
    let onSelectFavoriteStation: (FavoriteStation) -> Void
    let onAddPlace: (SavedPlace.Role) -> Void
    let onRemovePlace: (SavedPlace) -> Void
    let onRemoveFavoriteStation: (FavoriteStation) -> Void
    /// The horizontal inset of the surrounding list; the carousel escapes it
    /// so chips scroll to the sheet edge, and `contentMargins` restores it.
    var horizontalInset: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 10) {
                roleChip(home, role: .home, title: "Maison", systemImage: "house.fill")
                roleChip(work, role: .work, title: "Travail", systemImage: "briefcase.fill")

                ForEach(favoritePlaces) { place in
                    HomeShortcutChip(
                        title: place.name,
                        systemImage: "star.fill"
                    ) {
                        onSelectPlace(place)
                    }
                    .contextMenu {
                        Button("Retirer des favoris", systemImage: "star.slash", role: .destructive) {
                            onRemovePlace(place)
                        }
                    }
                }

                ForEach(favoriteStations) { favorite in
                    HomeShortcutChip(
                        title: favorite.name,
                        systemImage: "tram.fill"
                    ) {
                        onSelectFavoriteStation(favorite)
                    }
                    .contextMenu {
                        Button("Retirer des favoris", systemImage: "star.slash", role: .destructive) {
                            onRemoveFavoriteStation(favorite)
                        }
                    }
                }

                HomeShortcutChip(
                    title: "Favori",
                    systemImage: "plus",
                    isPlaceholder: true
                ) {
                    onAddPlace(.favorite)
                }
            }
            .padding(.vertical, 1)
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .padding(.horizontal, -horizontalInset)
    }

    private func roleChip(
        _ place: SavedPlace?,
        role: SavedPlace.Role,
        title: String,
        systemImage: String
    ) -> some View {
        HomeShortcutChip(
            title: title,
            systemImage: systemImage,
            isPlaceholder: place == nil
        ) {
            if let place {
                onSelectPlace(place)
            } else {
                onAddPlace(role)
            }
        }
        .contextMenu {
            if let place {
                Button("Modifier", systemImage: "pencil") {
                    onAddPlace(role)
                }
                Button("Supprimer", systemImage: "trash", role: .destructive) {
                    onRemovePlace(place)
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    HomeShortcutChipsView(
        home: nil,
        work: nil,
        favoritePlaces: [],
        favoriteStations: [
            FavoriteStation(
                stationID: "chatou",
                name: "Chatou - Croissy",
                coordinate: GeoCoordinate(latitude: 48.88, longitude: 2.15),
                savedAt: .now,
                updatedAt: .now
            )
        ],
        onSelectPlace: { _ in },
        onSelectFavoriteStation: { _ in },
        onAddPlace: { _ in },
        onRemovePlace: { _ in },
        onRemoveFavoriteStation: { _ in }
    )
    .padding()
}
