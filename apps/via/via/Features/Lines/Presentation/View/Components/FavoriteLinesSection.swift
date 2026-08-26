import SwiftUI

/// The always-visible quick-access strip at the top of the Lines catalogue.
struct FavoriteLinesSection: View {
  let lines: [LineStatus]

  var body: some View {
    Section {
      ScrollView(.horizontal) {
        LazyHStack(spacing: 12) {
          ForEach(lines) { status in
            NavigationLink(value: status) {
              FavoriteLineTile(status: status)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
      }
      .scrollIndicators(.hidden)
      .scrollClipDisabled()
      .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
    } header: {
      Text("Lignes favorites")
        .textCase(nil)
    }
  }
}
