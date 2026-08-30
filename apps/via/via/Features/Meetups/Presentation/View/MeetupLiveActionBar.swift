import SwiftUI

struct MeetupLiveActionBar: View {
    let isLive: Bool
    let includesLiveActivity: Bool
    let isDisabled: Bool
    let onToggleLiveActivity: () -> Void
    let onToggleLive: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var startTick = 0
    @State private var stopTick = 0

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))

            layout {
                if !isLive {
                    Button(action: onToggleLiveActivity) {
                        Label {
                            Text(includesLiveActivity ? "Live Activity activée" : "Ajouter une Live Activity")
                        } icon: {
                            Image(systemName: includesLiveActivity
                                ? "rectangle.inset.filled.and.person.filled"
                                : "rectangle.inset.filled.and.person.crop")
                                .stateSymbolTransition(value: includesLiveActivity)
                        }
                    }
                    .iconAction()
                    .toggleHaptic(on: includesLiveActivity)
                    .accessibilityValue(includesLiveActivity ? "Activée" : "Désactivée")
                }

                Button {
                    if isLive { stopTick += 1 } else { startTick += 1 }
                    onToggleLive()
                } label: {
                    Label {
                        Text(isLive ? "Arrêter le partage" : "Lancer mon trajet")
                    } icon: {
                        Image(systemName: isLive ? "stop.circle.fill" : "location.circle.fill")
                            .contentTransition(
                                reduceMotion
                                    ? .identity
                                    : .symbolEffect(
                                        .replace.magic(fallback: .offUp.byLayer),
                                        options: .nonRepeating
                                    )
                            )
                    }
                }
                .primaryAction(tint: isLive ? .red : .blue)
                .disabled(isDisabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
        .animation(reduceMotion ? nil : .default, value: isLive)
        .haptic(Haptic.started, on: startTick)
        .haptic(Haptic.ended, on: stopTick)
    }
}
