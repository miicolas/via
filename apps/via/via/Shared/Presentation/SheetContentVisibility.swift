import SwiftUI

extension EnvironmentValues {
    @Entry var sheetContentVisibilityProgress: CGFloat = 1
}

extension View {
    func sheetContentVisibilityRoot() -> some View {
        modifier(SheetContentVisibilityRootModifier())
    }

    func sheetContentVisibility() -> some View {
        modifier(SheetContentVisibilityModifier())
    }
}

private struct SheetContentVisibilityRootModifier: ViewModifier {
    private static let fadeStartHeight: CGFloat = 125
    private static let fadeDistance: CGFloat = 100

    @State private var progress: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .environment(\.sheetContentVisibilityProgress, progress)
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

private struct SheetContentVisibilityModifier: ViewModifier {
    @Environment(\.sheetContentVisibilityProgress) private var progress

    func body(content: Content) -> some View {
        content.opacity(progress)
    }
}
