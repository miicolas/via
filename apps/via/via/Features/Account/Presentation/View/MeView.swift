import SwiftUI

struct MeView: View {
    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress

    var body: some View {
        NavigationStack {
            List {

            }
            .navigationTitle("Me")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
        .opacity(tabVisibilityProgress)
    }
}
