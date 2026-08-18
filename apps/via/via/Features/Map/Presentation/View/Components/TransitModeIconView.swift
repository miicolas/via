import SwiftUI

struct TransitModeIconView: View {
    let mode: TransitMode

    var body: some View {
        Image(mode.logoAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: 32, height: 32)
            .accessibilityLabel(mode.displayName)
    }
}
