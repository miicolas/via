import SwiftUI

/// Lists the account's favorite stations and lets the user delete them
/// quickly, either by swiping a row or by emptying the whole list.
struct FavoritesSettingsView: View {
    let accountModel: AccountModel

    @State private var confirmClearAll = false

    private var favorites: [FavoriteStation] {
        accountModel.favorites
    }

    var body: some View {
        List {
            if favorites.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Aucune station favorite",
                        systemImage: "star",
                        description: Text("Ajoute une station en favori depuis sa fiche pour la retrouver ici.")
                    )
                }
            } else {
                Section {
                    ForEach(favorites) { favorite in
                        FavoriteStationRow(favorite: favorite)
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
        .navigationTitle("Favoris")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !favorites.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
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
}

private struct FavoriteStationRow: View {
    let favorite: FavoriteStation

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(favorite.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("Ajoutée \(favorite.savedAt.formatted(.relative(presentation: .named)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

#Preview("Favoris") {
    let accountModel: AccountModel = {
        let model = AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        model.activateAnonymous()
        model.toggleFavorite(
            stationID: StationID(rawValue: "1"),
            name: "Châtelet"
        )
        model.toggleFavorite(
            stationID: StationID(rawValue: "2"),
            name: "Gare de Lyon"
        )
        return model
    }()

    NavigationStack {
        FavoritesSettingsView(accountModel: accountModel)
    }
}
