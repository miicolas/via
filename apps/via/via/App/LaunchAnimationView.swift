import SwiftUI

struct LaunchAnimationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinished: () -> Void

    @State private var winkTrigger = 0
    @State private var hasStarted = false
    @State private var isCharacterVisible = false

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            animatedCharacter
                .frame(width: 104, height: 104)
                .opacity(isCharacterVisible ? 1 : 0)
                .accessibilityHidden(true)
        }
        .task {
            guard !hasStarted else { return }
            hasStarted = true

            if reduceMotion {
                isCharacterVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    isCharacterVisible = true
                }
            }

            await playAnimation()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Metyro")
    }

    private var animatedCharacter: some View {
        KeyframeAnimator(initialValue: CGFloat.zero, trigger: winkTrigger) { progress in
            character(progress: progress)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1, duration: 0.16)
                LinearKeyframe(1, duration: 0.12)
                CubicKeyframe(0, duration: 0.26)
            }
        }
    }

    private func character(progress: CGFloat) -> some View {
        ZStack {
            Image("LaunchSilhouette")
                .resizable()

            WinkingEyeShape(progress: progress)
                .fill(
                    LinearGradient(
                        colors: [
                            .white,
                            Color(red: 0.973, green: 0.984, blue: 1),
                            Color(red: 0.918, green: 0.961, blue: 0.980),
                            Color(red: 0.957, green: 0.941, blue: 1),
                        ],
                        startPoint: UnitPoint(x: 0.32, y: 0.38),
                        endPoint: UnitPoint(x: 0.65, y: 0.60)
                    )
                )
                .overlay {
                    WinkingEyeShape(progress: progress)
                        .stroke(.white.opacity(0.92), lineWidth: 0.25)
                }

            Image("LaunchRightEye")
                .resizable()
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func playAnimation() async {
        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            onFinished()
            return
        }

        try? await Task.sleep(for: .milliseconds(420))
        guard !Task.isCancelled else { return }

        winkTrigger += 1

        try? await Task.sleep(for: .milliseconds(840))
        guard !Task.isCancelled else { return }
        onFinished()
    }
}

#Preview {
    LaunchAnimationView(onFinished: {})
}
