import SwiftUI

extension View {
    /// Applies Via's shared detent, interaction, and wide-screen sheet behavior.
    func adaptiveSheetPresentation(
        compactDetents: Set<PresentationDetent>,
        wideDetents: Set<PresentationDetent>,
        selection: Binding<PresentationDetent>,
        isLargeScreen: Bool
    ) -> some View {
        modifier(
            AdaptiveSheetPresentationModifier(
                compactDetents: compactDetents,
                wideDetents: wideDetents,
                selection: selection,
                isLargeScreen: isLargeScreen
            )
        )
    }
}

private struct AdaptiveSheetPresentationModifier: ViewModifier {
    private static let panelWidth: CGFloat = 380
    private static let wideCornerRadius: CGFloat = 45

    let compactDetents: Set<PresentationDetent>
    let wideDetents: Set<PresentationDetent>
    @Binding var selection: PresentationDetent
    let isLargeScreen: Bool

    func body(content: Content) -> some View {
        content
            .sheetContentVisibilityRoot()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents(activeDetents, selection: $selection)
            .presentationBackgroundInteraction(.enabled)
            .presentationContentInteraction(.resizes)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(isLargeScreen ? Self.wideCornerRadius : nil)
            .adaptiveSheet(width: Self.panelWidth, isActive: isLargeScreen)
            .interactiveDismissDisabled()
    }

    private var activeDetents: Set<PresentationDetent> {
        isLargeScreen ? wideDetents : compactDetents
    }
}
