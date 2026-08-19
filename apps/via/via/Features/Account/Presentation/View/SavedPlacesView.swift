import SwiftUI

struct SavedPlacesView: View {
    let account: AccountModel
    let searchRepository: any SearchRepository

    @State private var editingRole: SavedPlace.Role?

    var body: some View {
        List {
            Section {
                ForEach([SavedPlace.Role.home, .work]) { role in
                    Button {
                        editingRole = role
                    } label: {
                        SavedPlaceRow(role: role, place: account.place(for: role))
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Maison et travail")
            } footer: {
                Text("Ces raccourcis restent disponibles dans la recherche.")
            }

            Section {
                let favorites = account.places.filter { $0.role == .favorite }
                if favorites.isEmpty {
                    ContentUnavailableView {
                        Label("Aucun lieu enregistré", systemImage: "mappin.and.ellipse")
                    } description: {
                        Text("Ajoute une adresse ou une station pour la retrouver rapidement.")
                    } actions: {
                        Button("Ajouter un lieu") {
                            editingRole = .favorite
                        }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(favorites) { place in
                        SavedPlaceRow(role: .favorite, place: place)
                            .swipeActions {
                                Button(role: .destructive) {
                                    account.removePlace(id: place.id)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                    }
                }

                Button {
                    editingRole = .favorite
                } label: {
                    Label("Ajouter un lieu", systemImage: "plus")
                }
            } header: {
                Text("Favoris d’adresse")
            }
        }
        .navigationTitle("Lieux enregistrés")
        .toolbarTitleDisplayMode(.inlineLarge)
        .sheet(item: $editingRole) { role in
            SearchManualDepartureView(repository: searchRepository) { result in
                account.setPlace(result, role: role)
            }
        }
    }
}

private struct SavedPlaceRow: View {
    let role: SavedPlace.Role
    let place: SavedPlace?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: role.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(role.displayTitle)
                    .foregroundStyle(.primary)
                if let place {
                    Text(place.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("À ajouter")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: place == nil ? "plus.circle" : "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(place == nil ? "Ajoute un lieu" : "Remplace ce lieu")
    }
}
