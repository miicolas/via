import SwiftUI

/// Peek heights of the journey sheet, shared with whoever drives its detent.
enum JourneySheetDetents {
    /// The closed journey detail keeps the navigation header and its primary
    /// action visible while leaving the map readable above the sheet.
    static let detailPeekHeight: CGFloat = 160

    /// While guidance runs the peek hosts the compact strip instead of a
    /// squashed navigation stack, so it needs the same room the tab sheet gives
    /// that strip.
    static func peekHeight(isGuiding: Bool) -> CGFloat {
        isGuiding
            ? SheetTabDetents.collapsedHeight(hasCompactContent: true)
            : detailPeekHeight
    }

    static func peek(isGuiding: Bool) -> PresentationDetent {
        .height(peekHeight(isGuiding: isGuiding))
    }
}
