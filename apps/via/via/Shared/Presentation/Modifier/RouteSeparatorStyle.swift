import SwiftUI

extension Image {
    /// The chevron between two line badges: the same mark wherever a journey is
    /// drawn as a chain of lines.
    func routeSeparatorStyle() -> some View {
        font(.system(size: 8, weight: .bold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}
