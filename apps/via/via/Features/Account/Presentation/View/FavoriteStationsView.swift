import SwiftUI

struct FavoriteStationsView: View {
    let account: AccountModel
    let onOpenSearch: () -> Void

    var body: some View {
        List {
            if account.favorites.isEmpty {
                ContentUnavailableView {
                    Label("Aucune station favorite", systemImage: "star")
                } description: {
                    Text("Ajoute une station depuis sa fiche pour la retrouver ici.")
                } actions: {
                    Button("Rechercher une station") {
                        onOpenSearch()
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(account.favorites) { favorite in
                        HStack(spacing: 14) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(favorite.name)
                                Text("Station favorite")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 44)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                account.removeFavorite(stationID: favorite.stationID)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Stations favorites")
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}
