import SwiftUI

struct OnboardingGateView<Content: View>: View {
    @Bindable var model: OnboardingModel
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if model.isCompleted {
                content()
            } else {
                OnboardingView(
                    onContinue: model.complete,
                    onSkip: model.skip
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isCompleted)
    }
}

#Preview {
    OnboardingGateView(model: OnboardingModel()) {
        Text("Via")
    }
}
