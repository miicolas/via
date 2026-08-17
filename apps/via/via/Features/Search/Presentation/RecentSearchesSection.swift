import SwiftUI

/// "Récents" header plus swipeable rows, shared by the home sheet and the
/// active-search suggestions.
struct RecentSearchesSection: View {
    let recentSearches: [RecentSearch]
    let onSelect: (RecentSearch) -> Void
    let onRemove: (RecentSearch) -> Void

    var body: some View {
        ViaSectionHeader("Récents")
            .padding(.top, 8)
            .padding(.bottom, 4)

        ForEach(recentSearches) { item in
            Button { onSelect(item) } label: {
                RecentSearchRow(recent: item)
            }
            .buttonStyle(.plain)
            .trailingSwipeToDelete("Effacer", systemImage: "trash") {
                onRemove(item)
            }
            Divider()
        }
    }
}
