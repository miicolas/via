import SwiftUI

/// The local search history shared by destination and departure search.
struct RecentSearchesSection: View {
    let searches: [RecentSearch]
    let accessibilityHint: String
    let onSelect: (RecentSearch) -> Void
    let onRemove: (RecentSearch) -> Void
    let onClear: () -> Void

    @State private var isClearConfirmationPresented = false

    init(
        searches: [RecentSearch],
        accessibilityHint: String,
        onSelect: @escaping (RecentSearch) -> Void,
        onRemove: @escaping (RecentSearch) -> Void,
        onClear: @escaping () -> Void,
    ) {
        self.searches = searches
        self.accessibilityHint = accessibilityHint
        self.onSelect = onSelect
        self.onRemove = onRemove
        self.onClear = onClear
    }

    var body: some View {
        Section {
            ForEach(searches) { recent in
                SearchResultRow(
                    result: recent.searchResult,
                    accessibilityHint: accessibilityHint,
                ) {
                    onSelect(recent)
                } onDelete: {
                    onRemove(recent)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                        onRemove(recent)
                    }
                    .labelStyle(.iconOnly)
                }
            }
        } header: {
            HStack {
                Text("Récentes")

                Spacer()

                Button("Tout effacer", systemImage: "trash", role: .destructive) {
                    isClearConfirmationPresented = true
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHint("Demande confirmation avant de supprimer tout l’historique local")
            }
        }
        .confirmationDialog(
            "Effacer les recherches récentes ?",
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible,
        ) {
            Button("Effacer les recherches récentes", role: .destructive) {
                onClear()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action supprime les destinations enregistrées sur cet appareil.")
        }
    }
}

#Preview {
    List {
        RecentSearchesSection(
            searches: [
                RecentSearch(
                    result: .previewAddress,
                    savedAt: .now,
                )
            ],
            accessibilityHint: "Relance un trajet vers cette destination",
            onSelect: { _ in },
            onRemove: { _ in },
            onClear: {},
        )
    }
    .listStyle(.plain)
}
