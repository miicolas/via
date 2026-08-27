import SwiftUI

/// The official Île-de-France Mobilités mark for a mode, drawn from the asset
/// catalog rather than an SF Symbol. Use it when the map needs to identify the
/// network represented by an annotation; filters use neutral SF Symbols.
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
