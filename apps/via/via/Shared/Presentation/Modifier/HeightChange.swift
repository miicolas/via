import SwiftUI

extension View {
    /// Measures a presented sheet's full height — safe area included — and
    /// reports it *already reduced* to what the caller needs.
    ///
    /// A sheet's height changes on every frame of a drag, so a view that stores
    /// the raw `CGFloat` re-evaluates its body at the display's refresh rate for
    /// the whole gesture. Reducing inside the transform means the action only
    /// fires when the reduced value changes — a Bool that flips twice per drag
    /// rather than a height that moves a hundred times. Pass `CGFloat` through
    /// unchanged only when the height itself drives something continuous.
    func onHeightChange<Value: Equatable>(
        for transform: @escaping (CGFloat) -> Value,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        background {
            Rectangle()
                .foregroundStyle(.clear)
                .onGeometryChange(for: Value.self) {
                    transform($0.size.height)
                } action: { newValue in
                    action(newValue)
                }
                .ignoresSafeArea()
        }
    }
}
