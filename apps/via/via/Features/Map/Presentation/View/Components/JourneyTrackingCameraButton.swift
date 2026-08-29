import SwiftUI

struct JourneyTrackingControl {
  let isFollowing: Bool
  let recenter: @MainActor () -> Void
}

struct JourneyTrackingCameraButton: View {
  let isFollowing: Bool
  let action: @MainActor () -> Void

  @State private var recenterTick = 0

  var body: some View {
    Button {
      recenterTick += 1
      action()
    } label: {
      Label {
        Text("Suivre ma position en 3D")
      } icon: {
        Image(systemName: StateSymbol.journeyTracking(isOn: isFollowing))
          .stateSymbolTransition(value: isFollowing)
      }
      .labelStyle(.iconOnly)
      .font(.system(size: 17, weight: .medium))
      .frame(width: 44, height: 44)
      .contentShape(.circle)
    }
    .iconAction(size: .small)
    .background(Color(.secondarySystemBackground), in: Circle())
    .foregroundStyle(isFollowing ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
    // The camera may leave follow mode because the traveller panned. Only the
    // explicit recenter tap is felt, never that automatic state change.
    .haptic(Haptic.tap, on: recenterTick)
    .accessibilityLabel("Suivre ma position en 3D")
    .accessibilityValue(isFollowing ? "Actif" : "Inactif")
    .accessibilityHint(
      isFollowing
        ? "Recentre la carte dans le sens du trajet"
        : "Reprend le suivi orienté dans le sens du trajet"
    )
  }
}
