import SwiftUI

/// Pure presentation decisions for the map shell. The view still owns the
/// state, but the transition rules live here where they can be table-tested.
enum MapShellPresentation {
    struct Detents {
        let active: PresentationDetent
        let detail: PresentationDetent
        let journey: PresentationDetent
    }

    static func detentAfterTabChange(
        from oldTab: MapShellTab,
        to newTab: MapShellTab,
        isLargeScreen: Bool,
        hasJourneySurface: Bool
    ) -> PresentationDetent? {
        if newTab == .search, oldTab != .search {
            return hasJourneySurface
                ? (isLargeScreen ? .fraction(0.97) : .fraction(0.45))
                : (isLargeScreen ? .fraction(0.97) : .large)
        }
        if newTab == .report, oldTab != .report {
            return isLargeScreen ? .fraction(0.97) : .large
        }
        if oldTab == .search, newTab != .search {
            return isLargeScreen ? .fraction(0.97) : .fraction(0.45)
        }
        if oldTab == .report, newTab != .report {
            return isLargeScreen ? .fraction(0.97) : .fraction(0.45)
        }
        return nil
    }

    static func naturalPanelTransition(
        wasVisible: Bool,
        isVisible: Bool
    ) -> NaturalPanelTransition? {
        if isVisible, !wasVisible { return .present }
        if wasVisible, !isVisible { return .dismiss }
        return nil
    }

    static func remapDetents(
        _ detents: Detents,
        isLargeScreen: Bool,
        collapsed: PresentationDetent,
        journeyPeek: PresentationDetent,
        detailCollapsed: PresentationDetent
    ) -> Detents {
        let active: PresentationDetent
        if isLargeScreen, detents.active != collapsed {
            active = .fraction(0.97)
        } else if !isLargeScreen, detents.active == .fraction(0.97) {
            active = .fraction(0.45)
        } else {
            active = detents.active
        }

        let detail: PresentationDetent
        if isLargeScreen, detents.detail != detailCollapsed {
            detail = .fraction(0.97)
        } else if !isLargeScreen, detents.detail == .fraction(0.97) {
            detail = .large
        } else {
            detail = detents.detail
        }

        let journey: PresentationDetent
        if isLargeScreen, detents.journey != journeyPeek {
            journey = .fraction(0.97)
        } else if !isLargeScreen, detents.journey == .fraction(0.97) {
            journey = .large
        } else {
            journey = detents.journey
        }

        return Detents(active: active, detail: detail, journey: journey)
    }
}

enum NaturalPanelTransition: Equatable {
    case present
    case dismiss
}
