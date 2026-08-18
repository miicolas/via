import SwiftUI

struct LinesView: View {
    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress

    var body: some View {
        NavigationStack {
            List {

            }
            .navigationTitle("Lines")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
        .opacity(tabVisibilityProgress)
    }
}
