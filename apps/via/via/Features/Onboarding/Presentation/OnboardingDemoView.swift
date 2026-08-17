import SwiftUI

struct OnboardingDemoView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: OnboardingDemoModel

    init(
        onContinue: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        initialPhase: OnboardingDemoPhase = .welcome
    ) {
        self.onContinue = onContinue
        self.onSkip = onSkip
        _model = State(initialValue: OnboardingDemoModel(phase: initialPhase))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OnboardingDemoMapView(
                presentation: model.journeyPresentation,
                reduceMotion: reduceMotion
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.32), .clear, .black.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            panel
        }
        .overlay(alignment: .topTrailing) {
            skipButton
        }
        .background(.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            panelContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.16), radius: 24, y: -8)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.25),
            value: model.phase
        )
    }

    private var skipButton: some View {
        Button("Passer", action: onSkip)
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 16)
            .padding(.trailing, 16)
            .accessibilityIdentifier("onboarding-skip")
            .accessibilityLabel("Passer l’introduction")
            .accessibilityHint("Ouvre directement la connexion")
    }

    @ViewBuilder
    private var panelContent: some View {
        switch model.phase {
        case .welcome:
            OnboardingWelcomeView(onStart: model.start)

        case .input:
            OnboardingDemoInputView(
                query: model.query,
                onSend: model.send
            )

        case .generating:
            NaturalJourneyLoadingView()

        case .result:
            NaturalJourneyAnswerCard(
                journey: model.journey,
                result: model.naturalJourneyResult,
                isOriginalAnswer: true,
                buttonAccessibilityIdentifier: "onboarding-demo-go",
                onGo: onContinue
            )
        }
    }
}

#Preview("Bienvenue") {
    OnboardingDemoView(onContinue: {}, onSkip: {})
}

#Preview("Saisie") {
    OnboardingDemoView(
        onContinue: {},
        onSkip: {},
        initialPhase: .input
    )
}

#Preview("Génération") {
    OnboardingDemoView(
        onContinue: {},
        onSkip: {},
        initialPhase: .generating
    )
}

#Preview("Résultat") {
    OnboardingDemoView(
        onContinue: {},
        onSkip: {},
        initialPhase: .result
    )
}
