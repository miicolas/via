import SwiftUI

extension EnvironmentValues {
    @Entry var sheetTabVisibilityProgress: CGFloat = 1
}

extension View {
    /// Publishes the sheet's fade progress derived from its live height.
    /// Apply once on the sheet's root content.
    func sheetTabVisibilityRoot() -> some View {
        modifier(SheetTabVisibilityRootModifier())
    }

    /// Fades the view with the enclosing sheet as it collapses toward the
    /// tab-bar detent. Apply on any screen hosted inside the sheet.
    func sheetTabVisibility() -> some View {
        modifier(SheetTabVisibilityModifier())
    }
}

/// Holding the drag-driven progress in this modifier (not in the sheet view)
/// keeps per-frame geometry updates from re-evaluating the sheet's body.
private struct SheetTabVisibilityRootModifier: ViewModifier {
    /// Height below which the sheet content is fully faded, leaving only the
    /// bottom tab/search chrome visible.
    private static let fadeStartHeight: CGFloat = 125
    /// Height range over which the fade runs from 0 to 1.
    private static let fadeDistance: CGFloat = 100

    @State private var progress: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .environment(\.sheetTabVisibilityProgress, progress)
            .background(
                Color.clear.onGeometryChange(for: CGSize.self) {
                    $0.size
                } action: { size in
                    let height = min(max(size.height - Self.fadeStartHeight, 0), Self.fadeDistance)
                    progress = height / Self.fadeDistance
                }
            )
    }
}

private struct SheetTabVisibilityModifier: ViewModifier {
    @Environment(\.sheetTabVisibilityProgress) private var progress

    func body(content: Content) -> some View {
        content.opacity(progress)
    }
}
