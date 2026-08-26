import SwiftUI

struct OnboardingProfileView: View {
    let model: OnboardingProfileModel
    let onBack: () -> Void
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var movesForward = true

    private let steps = OnboardingQuestion.allCases

    var body: some View {
        // The questions keep the presentation's stage: black ground, the same
        // glass panel, the same beads counting the steps. Only what stands on
        // the stage changes — a screenshot there, the answers here.
        OnboardingScaffold(
            onBack: goBack,
            backHint: step == 0
                ? "Revient à l’étape précédente"
                : "Revient à la question précédente"
        ) {
            questionStage
        } panel: {
            VStack(spacing: 10) {
                if let errorMessage = model.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                OnboardingStepIndicator(count: steps.count, currentIndex: step)

                Button(step == steps.count - 1 ? "Terminer" : "Continuer", action: advance)
                    .primaryAction(tint: .blue)
                    .padding(.horizontal, 30)
                    .disabled(!canAdvance)
            }
        }
    }

    /// One question is one screenful: the column is centred on the room the
    /// panel leaves it, and only scrolls where nothing could fit anyway — hence
    /// `.basedOnSize`.
    private var questionStage: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    OnboardingHeadline(
                        title: currentQuestion.title,
                        subtitle: currentQuestion.subtitle,
                        wraps: true
                    )

                    answers
                }
                .id(step)
                .transition(stepTransition)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var answers: some View {
        VStack(spacing: 8) {
            switch currentQuestion {
            case .pass:
                ForEach(TransitPassKind.allCases) { value in
                    OnboardingChoiceCard(
                        title: value.title,
                        systemImage: value.systemImage,
                        isSelected: model.selectedPass == value,
                        action: { model.selectedPass = value }
                    )
                }
            case .presence:
                ForEach(IleDeFrancePresence.allCases) { value in
                    OnboardingChoiceCard(
                        title: value.title,
                        systemImage: value.systemImage,
                        isSelected: model.selectedPresence == value,
                        action: { model.selectedPresence = value }
                    )
                }
            case .frequency:
                ForEach(TransitUsageFrequency.allCases) { value in
                    OnboardingChoiceCard(
                        title: value.title,
                        systemImage: value.systemImage,
                        isSelected: model.selectedFrequency == value,
                        action: { model.selectedFrequency = value }
                    )
                }
            }
        }
    }

    private var currentQuestion: OnboardingQuestion {
        steps[step]
    }

    private var canAdvance: Bool {
        switch currentQuestion {
        case .pass: model.selectedPass != nil
        case .presence: model.selectedPresence != nil
        case .frequency: model.selectedFrequency != nil
        }
    }

    /// The presentation's pages ride sideways in their carousel; a question
    /// leaves the same way — sliding towards where the traveller is headed —
    /// rather than dissolving in place.
    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movesForward ? .trailing : .leading),
            removal: .move(edge: movesForward ? .leading : .trailing)
        )
        .combined(with: .opacity)
    }

    private func advance() {
        guard canAdvance else { return }
        if step == steps.count - 1 {
            guard model.save() else { return }
            onComplete()
            return
        }

        movesForward = true
        withAnimation(stepAnimation) {
            step += 1
        }
    }

    /// The first question is not a wall: its chevron hands the traveller back
    /// to the screen before the questions, so the flow is never one-way.
    private func goBack() {
        guard step > 0 else {
            onBack()
            return
        }

        movesForward = false
        withAnimation(stepAnimation) {
            step -= 1
        }
    }

    /// The same spring the presentation's carousel rides, so a question
    /// arriving feels like one more page of the same deck.
    private var stepAnimation: Animation? {
        reduceMotion
            ? nil
            : .interpolatingSpring(duration: 0.65, bounce: 0, initialVelocity: 0)
    }
}

private enum OnboardingQuestion: Int, CaseIterable {
    case pass
    case presence
    case frequency

    var title: String {
        switch self {
        case .pass: "Quel titre utilises-tu ?"
        case .presence: "Tu es de passage en Île-de-France ?"
        case .frequency: "À quelle fréquence prends-tu les transports ?"
        }
    }

    var subtitle: String {
        switch self {
        case .pass: "On adapte les conseils à tes habitudes."
        case .presence: "Cela ajuste le niveau d’explication."
        case .frequency: "Il n’y a pas de mauvaise réponse."
        }
    }
}

#Preview("Profil de transport") {
    OnboardingProfileView(
        model: OnboardingProfileModel(store: InMemoryOnboardingProfileStore()),
        onBack: {},
        onComplete: {}
    )
}
