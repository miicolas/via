import SwiftUI

struct RecentSearchesView: View {
    let entries: [SearchResult]
    let onSelect: (SearchResult) -> Void
    let onRemove: (SearchResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recherches récentes")
                    .font(.headline)
                    .foregroundStyle(ViaTheme.ink)
                Spacer()
                Text("5 max.")
                    .font(.caption)
                    .foregroundStyle(ViaTheme.muted)
            }

            ForEach(entries) { entry in
                HStack(spacing: 6) {
                    SearchResultRowView(
                        result: entry,
                        action: { onSelect(entry) }
                    )
                    ViaButton(action: { onRemove(entry) }) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ViaTheme.muted)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Supprimer \(entry.name) des recherches récentes")
                }
            }
        }
    }
}
