import SwiftUI

/// Content of the dedicated search tab. Selecting the tab activates the field
/// thanks to `.tabViewSearchActivation(.searchTabSelection)` on the tab view.
struct SearchView: View {
    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress

    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            List {
                if !query.isEmpty {
                    Section("Résultats") {
                        Text("Recherche de « \(query) »…")
                            .foregroundStyle(.gray)
                    }
                }
            }
            .navigationTitle("Search")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(text: $query, prompt: "Stations, lignes, adresses")
        }
        .opacity(tabVisibilityProgress)
    }
}
