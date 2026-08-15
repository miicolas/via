import SwiftUI

struct MapSheetContainerView: View {
    let model: MapFeatureModel
    let featureFlags: NativeFeatureFlags
    let maxHeight: CGFloat
    let onOpenChat: () -> Void
    let onDragEnded: (CGFloat) -> Void
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency

    var body: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(ViaTheme.muted.opacity(0.45))
                .frame(width: 36, height: 5)
                .accessibilityLabel("Ajuster la hauteur du panneau")
                .accessibilityValue(detentLabel)
                .accessibilityAdjustableAction { direction in
                    onDragEnded(direction == .increment ? -40 : 40)
                }
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
        .background(
            accessibilityReduceTransparency
                ? AnyShapeStyle(ViaTheme.ground)
                : AnyShapeStyle(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 8)
    }

    private var detentLabel: String {
        switch model.flow.overviewDetentIndex {
        case 0: "Réduit"
        case 1: "Intermédiaire"
        default: "Développé"
        }
    }
}
