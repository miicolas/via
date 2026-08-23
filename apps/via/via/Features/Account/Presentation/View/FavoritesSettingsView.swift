import SwiftUI

/// Lists the account's favorite stations and lets the user delete them
/// quickly, either by swiping a row or by emptying the whole list.
struct FavoritesSettingsView: View {
    let accountModel: AccountModel
    let routesModel: FavoriteRoutesModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmClearAll = false
    @State private var editMode: EditMode = .inactive
    @State private var destinationPendingRemoval: SavedDestination?

    private var favorites: [FavoriteStation] {
        accountModel.favorites
    }

    private var destinations: [SavedDestination] {
        accountModel.destinations.sorted { $0.position < $1.position }
    }

    var body: some View {
        List {
            Section("Destinations") {
                ForEach(SavedPlace.Role.allCases) { role in
                    let place = accountModel.place(for: role)
                    SavedDestinationSettingsRow(
                        title: role.displayTitle,
                        subtitle: place?.name ?? "À configurer",
                        systemImage: SavedDestinationSymbols.resolved(
                            place?.systemImage ?? role.systemImage,
                            fallback: role.systemImage
                        ),
                        isConfigured: place != nil
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if place != nil {
                            Button("Effacer l’adresse", systemImage: "eraser", role: .destructive) {
                                accountModel.removePlace(for: role)
                            }
                            .labelStyle(.iconOnly)
                        }
                    }
                }

                ForEach(destinations) { destination in
                    SavedDestinationSettingsRow(
                        title: destination.label,
                        subtitle: destination.name,
                        systemImage: SavedDestinationSymbols.resolved(destination.systemImage),
                        isConfigured: true
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Supprimer", systemImage: "trash", role: .destructive) {
                            destinationPendingRemoval = destination
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                .onMove {
                    accountModel.reorderDestinations(from: $0, to: $1)
                }
            } footer: {
                Text("Maison et Travail restent épinglés. Réorganise les autres destinations en mode édition.")
            }

            if favorites.isEmpty {
                Section {
                    EmptyStateView(.noFavorites) {
                        EmptyStateHint(
                            Text("Touchez \(Image(systemName: "star")) sur la fiche d’une station pour la retrouver ici"),
                            label: "Touchez l’étoile sur la fiche d’une station pour la retrouver ici",
                        )
                    }
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(favorites) { favorite in
                        FavoriteStationRow(
                            favorite: favorite,
                            routes: routesModel.routesByStationID[favorite.stationID]
                        )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    remove(favorite)
                                } label: {
                                    Label("Supprimer", systemImage: "star.slash")
                                }
                            }
                    }
                    .onDelete(perform: remove)
                } header: {
                    Text(favorites.count == 1 ? "1 station" : "\(favorites.count) stations")
                } footer: {
                    Text("Balaye une station vers la gauche pour la retirer des favoris.")
                }

                Section {
                    Button(role: .destructive) {
                        confirmClearAll = true
                    } label: {
                        Label("Tout supprimer", systemImage: "trash")
                    }
                }
            }
        }
        .task(id: favorites.map(\.stationID)) {
            await routesModel.load(for: favorites)
        }
        .navigationTitle("Favoris")
        .toolbarTitleDisplayMode(.inlineLarge)
        .environment(\.editMode, $editMode)
        .toolbar {
            if !favorites.isEmpty || !destinations.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    } label: {
                        Image(systemName: editMode.isEditing ? "checkmark" : "pencil")
                            .contentTransition(
                                reduceMotion
                                    ? .identity
                                    : .symbolEffect(
                                        .replace.magic(fallback: .offUp.byLayer),
                                        options: .nonRepeating
                                    )
                            )
                    }
                    .accessibilityLabel("Modifier la liste")
                    .accessibilityValue(editMode.isEditing ? "Actif" : "Inactif")
                    .accessibilityHint("Active la réorganisation et la suppression des favoris.")
                }
            }
        }
        .onChange(of: favorites.isEmpty) { _, isEmpty in
            if isEmpty { editMode = .inactive }
        }
        .confirmationDialog(
            "Supprimer tous les favoris ?",
            isPresented: $confirmClearAll,
            titleVisibility: .visible
        ) {
            Button("Tout supprimer", role: .destructive) {
                clearAll()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Toutes les stations enregistrées seront retirées de tes favoris.")
        }
        .confirmationDialog(
            "Supprimer \(destinationPendingRemoval?.label ?? "ce favori") ?",
            isPresented: destinationRemovalPresentation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                guard let id = destinationPendingRemoval?.id else { return }
                accountModel.removeDestination(id: id)
                destinationPendingRemoval = nil
            }
            Button("Annuler", role: .cancel) {
                destinationPendingRemoval = nil
            }
        }
    }

    private func remove(_ favorite: FavoriteStation) {
        accountModel.removeFavorite(stationID: favorite.stationID)
    }

    private func remove(at offsets: IndexSet) {
        for index in offsets {
            accountModel.removeFavorite(stationID: favorites[index].stationID)
        }
    }

    private func clearAll() {
        for favorite in favorites {
            accountModel.removeFavorite(stationID: favorite.stationID)
        }
    }

    private var destinationRemovalPresentation: Binding<Bool> {
        Binding(
            get: { destinationPendingRemoval != nil },
            set: { if !$0 { destinationPendingRemoval = nil } }
        )
    }
}

#Preview("Favoris") {
    let accountModel: AccountModel = {
        let model = AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        model.activateAnonymous()
        for station in StationsArea.mapPreview.stations.prefix(2) {
            model.toggleFavorite(
                stationID: station.id,
                name: station.name,
                coordinate: station.coordinate
            )
        }
        return model
    }()

    NavigationStack {
        FavoritesSettingsView(
            accountModel: accountModel,
            routesModel: FavoriteRoutesModel(
                networkRepository: InMemoryNetworkRepository.mapPreview
            )
        )
    }
}
