import SwiftUI

/// Lists the account's favorite stations and lets the user delete them
/// quickly, either by swiping a row or by emptying the whole list.
struct FavoritesSettingsView: View {
    let accountModel: AccountModel
    let routesModel: FavoriteRoutesModel
    let searchViewModel: SearchViewModel
    var focus: FavoritesFocus? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmClearAll = false
    @State private var editMode: EditMode = .inactive
    @State private var destinationPendingRemoval: SavedDestination?
    @State private var selectionContext: SavedDestinationSelectionContext?
    @State private var draft: SavedDestinationDraft?
    @State private var pendingSelection: PendingSelection?
    @State private var pendingReplacement: SavedDestinationDraft?
    @State private var hasAppliedFocus = false

    /// A result chosen in the search sheet, waiting for that sheet to finish
    /// closing before the editor takes over.
    private struct PendingSelection {
        let result: SearchResult
        let context: SavedDestinationSelectionContext
    }

    private var favorites: [FavoriteStation] {
        accountModel.favorites
    }

    private var destinations: [SavedDestination] {
        accountModel.destinations.sorted { $0.position < $1.position }
    }

    var body: some View {
        List {
            Section {
                ForEach(SavedPlace.Role.allCases) { role in
                    let place = accountModel.place(for: role)
                    Button {
                        if let place {
                            draft = SavedDestinationEditing.draft(editing: place)
                        } else {
                            selectionContext = .place(role)
                        }
                    } label: {
                        SavedDestinationSettingsRow(
                            title: role.displayTitle,
                            subtitle: place?.name ?? "À configurer",
                            systemImage: SavedDestinationSymbols.resolved(
                                place?.systemImage ?? role.systemImage,
                                fallback: role.systemImage
                            ),
                            isConfigured: place != nil
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(
                        place == nil
                            ? "Choisit l’adresse de \(role.displayTitle)"
                            : "Modifie cette adresse"
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
                    Button {
                        draft = SavedDestinationEditing.draft(editing: destination)
                    } label: {
                        SavedDestinationSettingsRow(
                            title: destination.label,
                            subtitle: destination.name,
                            systemImage: SavedDestinationSymbols.resolved(destination.systemImage),
                            isConfigured: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Modifie ce favori")
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
            } header: {
                Text("Destinations")
            } footer: {
                if destinations.isEmpty {
                    EmptyStateHint(
                        Text("Touchez \(Image(systemName: "plus")) pour enregistrer un lieu"),
                        label: "Touchez le bouton plus pour enregistrer un lieu",
                    )
                } else {
                    Text("Maison et Travail restent épinglés. Réorganise les autres destinations en mode édition.")
                }
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
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ajouter une destination", systemImage: "plus") {
                    selectionContext = .destination
                }
                .labelStyle(.iconOnly)
                .disabled(hasReachedDestinationLimit)
                .accessibilityHint(
                    hasReachedDestinationLimit
                        ? "La limite de favoris est atteinte"
                        : "Recherche un lieu à enregistrer"
                )
            }

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
        .onAppear(perform: applyFocus)
        // The search hands over to the editor, and the editor can hand back
        // to the search. Each handover waits for `onDismiss` — presenting the
        // next sheet while the current one is still closing loses it.
        .sheet(item: $selectionContext, onDismiss: presentPendingDraft) { context in
            SavedDestinationSearchView(
                viewModel: searchViewModel,
                title: context.searchTitle,
                onSelect: { result in
                    pendingSelection = PendingSelection(result: result, context: context)
                }
            )
        }
        .sheet(item: $draft, onDismiss: presentPendingReplacement) { draft in
            SavedDestinationEditorView(
                draft: draft,
                onSave: { label, systemImage in
                    SavedDestinationEditing.save(
                        draft,
                        label: label,
                        systemImage: systemImage,
                        in: accountModel
                    )
                    self.draft = nil
                },
                onChangeDestination: { label, systemImage in
                    var replacement = draft
                    replacement.label = label
                    replacement.systemImage = systemImage
                    pendingReplacement = replacement
                    self.draft = nil
                },
                onDelete: SavedDestinationEditing.deleteAction(for: draft, in: accountModel),
                onClose: { self.draft = nil }
            )
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

    private var hasReachedDestinationLimit: Bool {
        destinations.count >= AccountLocalSnapshot.destinationLimit
    }

    /// Opens straight onto whatever the user tapped to get here — an empty
    /// Maison capsule, or the "+" of the shortcut rail.
    private func applyFocus() {
        guard !hasAppliedFocus, let focus else { return }
        hasAppliedFocus = true

        switch focus {
        case .place(let role):
            if let place = accountModel.place(for: role) {
                draft = SavedDestinationEditing.draft(editing: place)
            } else {
                selectionContext = .place(role)
            }
        case .addDestination:
            guard !hasReachedDestinationLimit else { return }
            selectionContext = .destination
        }
    }

    private func presentPendingDraft() {
        guard let pending = pendingSelection else { return }
        pendingSelection = nil
        draft = SavedDestinationEditing.draft(
            for: pending.result,
            context: pending.context,
            in: accountModel
        )
    }

    private func presentPendingReplacement() {
        guard let replacement = pendingReplacement else { return }
        pendingReplacement = nil
        selectionContext = .replacement(replacement)
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
            ),
            searchViewModel: SearchViewModel(
                repository: InMemorySearchRepository.preview,
                journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
                locationModel: LocationModel(adapter: InMemoryLocationAdapter())
            )
        )
    }
}
