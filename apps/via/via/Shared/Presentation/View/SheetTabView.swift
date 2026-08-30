import SwiftUI

extension EnvironmentValues {
    /// 0 when the sheet sits at its collapsed detent, 1 once it is tall enough to show tab content.
    @Entry var sheetTabVisibilityProgress: CGFloat = 1
    /// True while compact content or a shell-owned control occupies the bottom slot.
    @Entry var sheetHidesTabBar: Bool = false
}

extension View {
    /// Tab contents opt into the container's tab bar visibility. The modifier
    /// has to sit *inside* a tab: applied to the `TabView` itself, UIKit never
    /// forwards it to the tab bar.
    func sheetTabBarVisibility() -> some View {
        modifier(SheetTabBarVisibility())
    }
}

private struct SheetTabBarVisibility: ViewModifier {
    @Environment(\.sheetHidesTabBar) private var isHidden

    func body(content: Content) -> some View {
        content.toolbarVisibility(isHidden ? .hidden : .automatic, for: .tabBar)
    }
}

/// The detent paired with the tab it was measured against, so a detent that
/// moved *because* the tab moved can be told apart from one the thumb dragged.
private struct DetentWitness<Selection: Hashable>: Equatable {
    let detent: PresentationDetent
    let selection: Selection
}

/// Detent contract of the map sheet, shared with whoever drives `activeDetent`.
enum SheetTabDetents {
    /// How far past the collapsed height the sheet has to travel before the tab
    /// content is fully faded in.
    private static let revealRange: CGFloat = 100
    /// Slack above the collapsed height, so resting there does not already start
    /// revealing the content underneath.
    private static let restSlack: CGFloat = 35

    /// With a journey running the collapsed sheet drops the tab bar and hosts
    /// the compact journey view instead, which needs room for four rows.
    ///
    /// The height is measured off those rows rather than rounded up: the
    /// previous 136 left a band of empty sheet under the "Puis" row, which read
    /// as the guidance having been cut short.
    static func collapsedHeight(hasCompactContent: Bool) -> CGFloat {
        hasCompactContent ? 116 : 90
    }

    static func collapsed(hasCompactContent: Bool) -> PresentationDetent {
        .height(collapsedHeight(hasCompactContent: hasCompactContent))
    }

    /// 0 while the sheet rests at its collapsed height, 1 once it has grown a
    /// `revealRange` past it.
    ///
    /// The baseline follows the collapsed height instead of being a constant.
    /// With a fixed one the taller journey detent already scored a third of
    /// the way in, so the compact view never earned its place at its own
    /// detent: the sheet rested there showing the tab content at a third of its
    /// opacity, squashed behind the navigation bar.
    static func contentProgress(sheetHeight: CGFloat, hasCompactContent: Bool) -> CGFloat {
        let base = collapsedHeight(hasCompactContent: hasCompactContent) + restSlack
        return min(max(sheetHeight - base, 0), revealRange) / revealRange
    }
}

enum SheetTabPresentation {
    static func showsCompactContent(
        isEligible: Bool,
        measuredContentProgress: CGFloat
    ) -> Bool {
        isEligible && measuredContentProgress <= 0.01
    }

    /// The compact journey view replaces the tab's navigation content.
    /// Keeping both eligible for display makes short sheets show two copies of
    /// the same guidance and lets the navigation bar overlap it.
    static func contentVisibilityProgress(
        measuredProgress: CGFloat,
        isCompactVisible: Bool
    ) -> CGFloat {
        isCompactVisible ? 0 : measuredProgress
    }
}

/// Tab container for the persistent map sheet: owns the detent set, fades tab
/// content in as the sheet grows past the collapsed detent, and hands the
/// collapsed sheet over to `compactContent` when there is something to say at
/// that height.
struct SheetTabView<Selection: Hashable, TabC: TabContent<Selection>, Compact: View>: View {
    @Binding var selection: Selection
    @Binding var activeDetent: PresentationDetent
    var isLargeScreen: Bool
    var isAnotherSheetPresenting: Bool = false
    /// Lets a shell-owned control temporarily occupy the tab bar's safe-area
    /// slot without drawing on top of the tab items.
    var hidesTabBar: Bool = false
    /// A full-screen task owns the sheet until it is explicitly closed. Keeping
    /// only the expanded detent prevents its content being crushed by a drag.
    var locksExpandedDetent: Bool = false
    /// Keeps room for the compact content in the collapsed detent. Stays true
    /// for the whole journey so the detent set does not change under the sheet.
    var reservesCompactSpace: Bool = false
    /// Shows the compact content. The guidance screen already states the current
    /// step, so it only earns its place once the sheet is put away.
    var isCompactVisible: Bool = false
    @ViewBuilder var compactContent: () -> Compact
    @TabContentBuilder<Selection> var tabs: TabC

    @State private var tabVisibilityProgress: CGFloat = 0

    var body: some View {
        tabView
        .tabViewSearchActivation(.searchTabSelection)
        .environment(
            \.sheetTabVisibilityProgress,
            SheetTabPresentation.contentVisibilityProgress(
                measuredProgress: tabVisibilityProgress,
                isCompactVisible: showsCompactContent
            )
        )
        // Read inside each tab by `sheetTabBarVisibility()`.
        .environment(\.sheetHidesTabBar, showsCompactContent || hidesTabBar)
        .overlay(alignment: .top) { compactOverlay }
        .presentationDetents(detents, selection: .init(get: {
            if locksExpandedDetent {
                return expandedDetent
            }

            // A detail sheet cannot stack above a .large parent; pin just below full height.
            if activeDetent == .large && isAnotherSheetPresenting {
                return isLargeScreen ? .fraction(0.97) : .fraction(0.98)
            }

            return activeDetent
        }, set: { detent in
            activeDetent = detent
        }))
        .presentationCornerRadius(isLargeScreen ? 45 : nil)
        .presentationDragIndicator(locksExpandedDetent ? .hidden : .automatic)
        .presentationBackgroundInteraction(.enabled)
        // The root sheet is the most-dragged surface in the app: it snaps to a
        // detent under the thumb and, once guidance runs, jumps on its own.
        // Switching tab moves the detent too, and one gesture owes one answer —
        // so the detent stays quiet whenever the tab moved with it.
        .haptic(
            Haptic.advanced,
            on: DetentWitness(detent: activeDetent, selection: selection)
        ) { $0.selection == $1.selection }
        .haptic(Haptic.selection, on: selection)
        .interactiveDismissDisabled()
        .onHeightChange(for: contentProgress(sheetHeight:)) { newValue in
            tabVisibilityProgress = newValue
        }
    }

    /// Sits above the (faded out) tab content rather than inside a tab, so it
    /// survives tab switches and keeps its place while the tab bar leaves.
    @ViewBuilder
    private var compactOverlay: some View {
        if showsCompactContent {
            compactContent()
                // Clears the drag indicator the sheet draws at its top edge.
                .padding(.top, 16)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var tabView: some View {
        // The modifier stays attached in every state: branching around the
        // TabView itself would change its identity and reset the selected tab.
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

    /// The progress the fade and the strip both read, resolved as the sheet is
    /// measured rather than stored as a raw height.
    private func contentProgress(sheetHeight: CGFloat) -> CGFloat {
        SheetTabDetents.contentProgress(
            sheetHeight: sheetHeight,
            hasCompactContent: reservesCompactSpace
        )
    }

    private var showsCompactContent: Bool {
        SheetTabPresentation.showsCompactContent(
            isEligible: isCompactVisible,
            measuredContentProgress: tabVisibilityProgress
        )
    }

    private var detents: Set<PresentationDetent> {
        let collapsed = SheetTabDetents.collapsed(hasCompactContent: reservesCompactSpace)

        if locksExpandedDetent {
            return [expandedDetent]
        }

        if isLargeScreen {
            return [collapsed, .fraction(0.97)]
        }

        if isAnotherSheetPresenting {
            return [collapsed, .fraction(0.45), .fraction(0.98), .large]
        }

        return [collapsed, .fraction(0.45), .large]
    }

    private var expandedDetent: PresentationDetent {
        isLargeScreen ? .fraction(0.97) : .large
    }
}
