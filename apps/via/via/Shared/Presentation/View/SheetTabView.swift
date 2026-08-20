import SwiftUI

extension EnvironmentValues {
    /// 0 when the sheet sits at its collapsed detent, 1 once it is tall enough to show tab content.
    @Entry var sheetTabVisibilityProgress: CGFloat = 1
}

/// Detent contract of the map sheet, shared with whoever drives `activeDetent`.
enum SheetTabDetents {
    /// The collapsed height has to make room for the tab bar accessory,
    /// otherwise an active journey bar is clipped away at rest.
    static func collapsed(hasAccessory: Bool) -> PresentationDetent {
        hasAccessory ? .height(158) : .height(90)
    }
}

enum SheetTabPresentation {
    static func showsAccessory(
        isEligible: Bool,
        measuredContentProgress: CGFloat
    ) -> Bool {
        isEligible && measuredContentProgress <= 0.01
    }

    /// The compact journey accessory replaces the tab's navigation content.
    /// Keeping both eligible for display makes short sheets show two copies of
    /// the same guidance and lets the navigation bar overlap the accessory.
    static func contentVisibilityProgress(
        measuredProgress: CGFloat,
        isAccessoryVisible: Bool
    ) -> CGFloat {
        isAccessoryVisible ? 0 : measuredProgress
    }
}

/// Tab container for the persistent map sheet: owns the detent set and fades
/// tab content in as the sheet grows past the collapsed detent.
struct SheetTabView<Selection: Hashable, TabC: TabContent<Selection>, Accessory: View>: View {
    @Binding var selection: Selection
    @Binding var activeDetent: PresentationDetent
    var isLargeScreen: Bool
    var isAnotherSheetPresenting: Bool = false
    /// Keeps room for the accessory in the collapsed detent. Stays true for the
    /// whole journey so the detent set does not change under the sheet.
    var reservesAccessorySpace: Bool = false
    /// Shows the accessory. The guidance screen already states the current step,
    /// so the bar only earns its place once the sheet is put away.
    var isAccessoryVisible: Bool = false
    @ViewBuilder var accessory: () -> Accessory
    @TabContentBuilder<Selection> var tabs: TabC

    @State private var tabVisibilityProgress: CGFloat = 0

    var body: some View {
        tabView
        .tabViewSearchActivation(.searchTabSelection)
        .environment(
            \.sheetTabVisibilityProgress,
            SheetTabPresentation.contentVisibilityProgress(
                measuredProgress: tabVisibilityProgress,
                isAccessoryVisible: showsAccessory
            )
        )
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
        // The modifier stays attached in every state: branching around the
        // TabView itself would change its identity and reset the selected tab.
        let base = accessorised(
            TabView(selection: $selection) {
                tabs
            }
        )

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

    /// `isEnabled:` is the supported way to hide the accessory; on 26.0 an
    /// empty accessory body is the only lever available.
    @ViewBuilder
    private func accessorised(_ content: some View) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: showsAccessory) { accessory() }
        } else {
            content.tabViewBottomAccessory { if showsAccessory { accessory() } }
        }
    }

    private var showsAccessory: Bool {
        SheetTabPresentation.showsAccessory(
            isEligible: isAccessoryVisible,
            measuredContentProgress: tabVisibilityProgress
        )
    }

    private var detents: Set<PresentationDetent> {
        let collapsed = SheetTabDetents.collapsed(hasAccessory: reservesAccessorySpace)

        if isLargeScreen {
            return [collapsed, .fraction(0.97)]
        }

        if isAnotherSheetPresenting {
            return [collapsed, .fraction(0.45), .fraction(0.98), .large]
        }

        return [collapsed, .fraction(0.45), .large]
    }
}
