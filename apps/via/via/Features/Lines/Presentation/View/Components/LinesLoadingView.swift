import SwiftUI

struct LinesLoadingView: View {
  var body: some View {
    LinesStateScreen {
      SkeletonList(
        count: 6,
        label: "Chargement des lignes…",
        row: .lineStatus
      )
      .padding(.horizontal, 20)
      .frame(maxWidth: .infinity, alignment: .top)
    }
  }
}
