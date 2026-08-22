import SwiftUI

/// A square glass action: the pair of large glyphs that ends a detail screen,
/// where two full-width capsules would take the whole sheet and a round
/// `iconAction` would read as an aside rather than as the thing to tap.
///
/// The busy spinner, the 60pt square and the symbol transition live here so
/// the two buttons of a bar cannot drift apart, and so a third bar gets them
/// for free.
struct GlyphActionButton<Value: Equatable>: View {
  let systemImage: String
  var isProminent = false
  var isBusy = false
  /// What the glyph is derived from, so the swap animates.
  let value: Value
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if isBusy {
          ProgressView()
            .controlSize(.small)
            .tint(isProminent ? .white : nil)
        } else {
          Image(systemName: systemImage)
            .font(.title3.weight(.bold))
            .stateSymbolTransition(value: value)
        }
      }
      .frame(width: 60, height: 60)
    }
    .glyphAction(isProminent: isProminent)
  }
}

extension View {
  /// The shape of a square glass action. Separate from the button above so a
  /// caller needing its own label still lands on the same geometry.
  @ViewBuilder
  func glyphAction(isProminent: Bool = false) -> some View {
    let base = buttonBorderShape(.roundedRectangle(radius: 18))

    if isProminent {
      base.buttonStyle(.glassProminent).tint(.accentColor)
    } else {
      base.buttonStyle(.glass)
    }
  }
}
