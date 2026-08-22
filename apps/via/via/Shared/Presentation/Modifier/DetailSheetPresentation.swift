import SwiftUI

extension View {
    func detailSheetPresentation(
        isLargeScreen: Bool,
        collapsedHeight: CGFloat = DetailSheetPresentation.collapsedHeight,
        selection: Binding<PresentationDetent>
    ) -> some View {
        modifier(DetailSheetPresentationModifier(
            isLargeScreen: isLargeScreen,
            collapsedHeight: collapsedHeight,
            selection: selection
        ))
    }
}

enum DetailSheetPresentation {
    /// The peek: tall enough for the navigation title, short enough that the map
    /// keeps the screen. Sheets whose collapsed state has something else to say
    /// pass their own height.
    static let collapsedHeight: CGFloat = 80

    /// The top of the detent set below — what a sheet raises itself to. Views
    /// that drive a detent programmatically must ask for it here: a hand-written
    /// copy that drifts targets a detent this modifier no longer offers, and the
    /// sheet silently refuses to move.
    static func expanded(isLargeScreen: Bool) -> PresentationDetent {
        isLargeScreen ? .fraction(0.97) : .large
    }
}

private struct DetailSheetPresentationModifier: ViewModifier {
    let isLargeScreen: Bool
    let collapsedHeight: CGFloat
    @Binding var selection: PresentationDetent

    func body(content: Content) -> some View {
        content
            .presentationDetents(detents, selection: $selection)
            .presentationCornerRadius(isLargeScreen ? 45 : nil)
            .adaptiveSheet(380, isActive: isLargeScreen)
            .presentationBackgroundInteraction(.enabled)
            .interactiveDismissDisabled()
            .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    private var detents: Set<PresentationDetent> {
        [
            .height(collapsedHeight),
            DetailSheetPresentation.expanded(isLargeScreen: isLargeScreen)
        ]
    }
}
