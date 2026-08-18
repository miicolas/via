import SwiftUI

struct TransitModeIconView: View {
    let mode: TransitMode

    var body: some View {
        mode.glyph
            .font(.system(size: 8, weight: .heavy, design: .rounded))
            .foregroundStyle(.primary.opacity(0.82))
            .padding(.horizontal, 4)
            .frame(minWidth: 18, minHeight: 18)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.primary.opacity(0.14), lineWidth: 0.5)
            }
            .accessibilityLabel(mode.displayName)
    }
}
