import SwiftUI

struct RecentSearchesView: View {
    let account: AccountModel

    @State private var isClearConfirmationPresented = false

    var body: some View {
        List {
            if account.recentSearches.isEmpty {
                ContentUnavailableView {
                    Label("Aucune recherche récente", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Tes dernières recherches apparaîtront ici.")
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(account.recentSearches) { recent in
                        HStack(spacing: 14) {
                            Image(systemName: recent.kind == .station ? "tram.fill" : "mappin.and.ellipse")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(recent.name)
                                if let context = recent.context, !context.isEmpty {
                                    Text(context)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .frame(minHeight: 44)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                account.removeRecentSearch(id: recent.id)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }

                Section {
                    Button("Effacer l’historique", role: .destructive) {
                        isClearConfirmationPresented = true
                    }
                }
            }
        }
        .navigationTitle("Historique")
        .toolbarTitleDisplayMode(.inlineLarge)
        .confirmationDialog(
            "Effacer l’historique ?",
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Effacer l’historique", role: .destructive) {
                account.clearRecentSearches()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action efface les recherches enregistrées sur tes espaces Via.")
        }
    }
}
