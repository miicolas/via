import SwiftUI

/// A Lines state that takes the whole tab: the column hugs its content, so the
/// scroll view is what makes it fill the screen and stay pull-to-refreshable.
struct LinesStateScreen<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    ScrollView {
      content()
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical)
    }
    .background(.background)
  }
}
