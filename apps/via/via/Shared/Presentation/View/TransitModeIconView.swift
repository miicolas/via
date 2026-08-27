import SwiftUI

/// The official Île-de-France Mobilités mark for a mode, drawn from the asset
/// catalog rather than an SF Symbol. Use it when a surface identifies the
/// network mode, including annotations, filters, and preferences.
struct TransitModeIconView: View {
    let mode: TransitMode
    var size: CGFloat = 32

    var body: some View {
        Image(mode.logoAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(mode.displayName)
    }
}
