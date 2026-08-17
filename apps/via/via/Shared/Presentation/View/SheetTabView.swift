import SwiftUI

extension EnvironmentValues {
    /// 0 when the sheet sits at its collapsed detent, 1 once it is tall enough to show tab content.
    @Entry var sheetTabVisibilityProgress: CGFloat = 1
}

/// Tab container for the persistent map sheet: owns the detent set and fades
/// tab content in as the sheet grows past the collapsed detent.
struct SheetTabView<Selection: Hashable, TabC: TabContent<Selection>>: View {
    @Binding var selection: Selection
    @Binding var activeDetent: PresentationDetent
    var isLargeScreen: Bool
    var isAnotherSheetPresenting: Bool = false
    @TabContentBuilder<Selection> var tabs: TabC

    @State private var tabVisibilityProgress: CGFloat = 0

    var body: some View {
        tabView
        .tabViewSearchActivation(.searchTabSelection)
        .environment(\.sheetTabVisibilityProgress, tabVisibilityProgress)
        .presentationDetents(detents, selection: .init(get: {
            // A detail sheet cannot stack above a .large parent; pin just below full height.
            if activeDetent == .large && isAnotherSheetPresenting {
                return isLargeScreen ? .fraction(0.97) : .fraction(0.98)
            }

            return activeDetent
        }, set: { detent in
            activeDetent = detent
        }))
        .presentationCornerRadius(isLargeScreen ? 45 : nil)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled()
        .background {
            Rectangle()
                .foregroundStyle(.clear)
                .onGeometryChange(for: CGSize.self) {
                    $0.size
                } action: { newValue in
                    let height = min(max(newValue.height - 125, 0), 100)
                    tabVisibilityProgress = height / 100
                }
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var tabView: some View {
        let base = TabView(selection: $selection) {
            tabs
        }

        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            base.navigationTransition(.crossFade)
        } else {
            base
        }
        #else
        base
        #endif
    }

    private var detents: Set<PresentationDetent> {
        if isLargeScreen {
            return [.height(90), .fraction(0.97)]
        }

        if isAnotherSheetPresenting {
            return [.height(90), .fraction(0.45), .fraction(0.98), .large]
        }

        return [.height(90), .fraction(0.45), .large]
    }
}
