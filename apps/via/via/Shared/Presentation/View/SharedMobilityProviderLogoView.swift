import SwiftUI

/// A small, local operator mark used anywhere shared mobility is named.
///
/// The white tile keeps dark and light brand marks legible on both the map and
/// the material cards. The accessibility label belongs to the surrounding
/// row, so the logo itself stays decorative when it is shown beside text.
struct SharedMobilityProviderLogoView: View {
    let provider: SharedMobilityProvider
    var size: CGFloat = 24

    var body: some View {
        Image(provider.logoAssetName)
            .resizable()
            .scaledToFit()
            .padding(size * 0.12)
            .frame(width: size + 8, height: size + 8)
            .background(.white, in: .rect(cornerRadius: (size + 8) * 0.25))
            .overlay {
                RoundedRectangle(cornerRadius: (size + 8) * 0.25)
                    .stroke(.black.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            .accessibilityHidden(true)
    }
}
