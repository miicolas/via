import SwiftUI

extension View {
    /// Keeps a sheet full height and anchored to the leading edge on wide screens.
    func adaptiveSheet(width: CGFloat, isActive: Bool) -> some View {
        presentationCompactAdaptation(.none)
            .background {
                AdaptiveSheetController(width: width, isActive: isActive)
            }
    }
}
