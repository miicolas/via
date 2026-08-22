import SwiftUI

extension View {
    /// The card surface a detail screen stacks: raised ground, generous inset,
    /// a soft corner and barely any shadow. Every card on a screen must agree on
    /// all four — a radius or an elevation that drifts by a copy-paste reads as
    /// two different materials scrolling past each other.
    func detailCard() -> some View {
        padding(20)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }
}
