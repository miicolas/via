import SwiftUI

extension Color {
    static let aiAccent = Color.purple
    static let aiSurface = Color.purple.opacity(0.08)
    /// The palette every Apple Intelligence surface in Via shares: the beam
    /// traced around an entry point and the thinking orb are the same light.
    static let aiPalette: [Color] = [.blue, .indigo, .purple, .pink]
}

extension View {
    /// The Apple Intelligence beam, traced along an arbitrary shape so round
    /// controls keep a round halo. Defined once so every AI surface in the app
    /// animates with the same palette.
    func aiBeam(in shape: some Shape, blur: CGFloat = 15, isEnabled: Bool) -> some View {
        borderBeam(
            border: .white,
            beam: Color.aiPalette,
            beamBlur: blur,
            shape: shape,
            isEnabled: isEnabled,
        )
    }
}
