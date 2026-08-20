import SwiftUI

extension View {
    func detailSheetPresentation(
        isLargeScreen: Bool,
        selection: Binding<PresentationDetent>
    ) -> some View {
        modifier(DetailSheetPresentationModifier(
            isLargeScreen: isLargeScreen,
            selection: selection
        ))
    }
}

private struct DetailSheetPresentationModifier: ViewModifier {
    let isLargeScreen: Bool
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
        if isLargeScreen {
            return [.height(80), .fraction(0.97)]
        }
        return [.height(80), .large]
    }
}
