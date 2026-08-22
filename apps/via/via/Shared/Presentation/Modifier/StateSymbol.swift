import SwiftUI

/// The SF Symbols Via swaps to report a state, named once so two screens
/// cannot report the same state with different glyphs.
enum StateSymbol {
  /// A reminder or a follow: filled once it is on.
  static func bell(isOn: Bool) -> String {
    isOn ? "bell.fill" : "bell"
  }

  /// A favourite.
  static func star(isOn: Bool) -> String {
    isOn ? "star.fill" : "star"
  }
}

extension View {
  /// A symbol that changes with state animates the change — Via's rule for
  /// every glyph the traveller can flip, not just toolbar icons.
  ///
  /// `value` is what the glyph is derived from: state that lands from an
  /// `async` task carries no transaction, so the animation is bound here
  /// rather than left to the caller's implicit one. Reduce Motion drops both
  /// halves, which is why they travel together.
  func stateSymbolTransition(value: some Equatable) -> some View {
    modifier(StateSymbolTransition(value: value))
  }
}

private struct StateSymbolTransition<Value: Equatable>: ViewModifier {
  let value: Value

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content
      .contentTransition(
        reduceMotion
          ? .identity
          : .symbolEffect(
            .replace.magic(fallback: .offUp.byLayer),
            options: .nonRepeating
          )
      )
      .animation(reduceMotion ? nil : .default, value: value)
  }
}
