import SwiftUI

struct MapSheetContainerView: View {
    let model: MapFeatureModel
    let featureFlags: NativeFeatureFlags
    let maxHeight: CGFloat
    let onOpenChat: () -> Void
    let onDragEnded: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(ViaTheme.muted.opacity(0.45))
                .frame(width: 36, height: 5)
                .accessibilityLabel("Ajuster la hauteur du panneau")
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            onDragEnded(value.translation.height)
                        }
                )

            MapSheetView(
                model: model,
                featureFlags: featureFlags,
                onOpenChat: onOpenChat
            )
            .frame(maxHeight: maxHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 8)
    }
}
