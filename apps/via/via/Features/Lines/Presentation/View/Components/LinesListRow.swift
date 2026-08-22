import SwiftUI

extension View {
  /// A card standing on the plain Lines list: the list draws no chrome of its
  /// own, so every row states the same inset once instead of five times.
  func linesCardRow(top: CGFloat = 6, bottom: CGFloat = 6) -> some View {
    listRowInsets(EdgeInsets(top: top, leading: 16, bottom: bottom, trailing: 16))
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
  }
}
