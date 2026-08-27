import SwiftUI

/// Restores the navigation camera after the traveller has explored the map.
/// The target is supplied by the map so the same control recentres on either
/// the native GPS dot or Via's estimated orange dot.
struct JourneyMapRecenterButton: View {
  let isFollowing: Bool
  let isEstimated: Bool
  let action: () -> Void

  @State private var tapTick = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Button {
      tapTick += 1
      action()
    } label: {
      Image(systemName: "location.fill")
    }
    .iconAction(isProminent: isFollowing)
    .tint(isEstimated ? .orange : .blue)
    .animation(reduceMotion ? nil : .default, value: isEstimated)
    .haptic(Haptic.tap, on: tapTick)
    .accessibilityLabel("Recentrer sur votre position")
    .accessibilityValue(isFollowing ? "Suivi actif" : "Suivi suspendu")
    .accessibilityHint("Recentre la carte et reprend le suivi du trajet")
  }
}

#Preview {
  JourneyMapRecenterButton(isFollowing: false, isEstimated: true) {}
    .padding()
}
