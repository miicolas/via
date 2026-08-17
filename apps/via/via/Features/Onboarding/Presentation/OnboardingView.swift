import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingDemoView(
            onContinue: onContinue,
            onSkip: onSkip
        )
    }
}

#Preview {
    OnboardingView(onContinue: {}, onSkip: {})
}
