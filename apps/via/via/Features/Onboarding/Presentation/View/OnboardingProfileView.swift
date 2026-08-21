import SwiftUI

struct OnboardingProfileView: View {
    let model: OnboardingProfileModel
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    private let steps = OnboardingQuestion.allCases

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    questionContent
                    actionBlock
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Question précédente", systemImage: "chevron.left") {
                    withAnimation(reduceMotion ? nil : .snappy) {
                        step = max(0, step - 1)
                    }
                }
                .iconAction()
                .disabled(step == 0)
                .opacity(step == 0 ? 0 : 1)
                .accessibilityHidden(step == 0)

                Spacer()

                Text("\(step + 1) sur \(steps.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(step + 1), total: Double(steps.count))
                .tint(.accentColor)
                .accessibilityLabel("Étape \(step + 1) sur \(steps.count)")
        }
    }

    @ViewBuilder
    private var questionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currentQuestion.title)
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(currentQuestion.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                switch currentQuestion {
                case .pass:
                    ForEach(TransitPassKind.allCases) { value in
                        OnboardingChoiceCard(
                            title: value.title,
                            subtitle: value.subtitle,
                            systemImage: value.systemImage,
                            isSelected: model.selectedPass == value,
                            action: { model.selectedPass = value }
                        )
                    }
                case .presence:
                    ForEach(IleDeFrancePresence.allCases) { value in
                        OnboardingChoiceCard(
                            title: value.title,
                            subtitle: value.subtitle,
                            systemImage: value.systemImage,
                            isSelected: model.selectedPresence == value,
                            action: { model.selectedPresence = value }
                        )
                    }
                case .frequency:
                    ForEach(TransitUsageFrequency.allCases) { value in
                        OnboardingChoiceCard(
                            title: value.title,
                            subtitle: value.subtitle,
                            systemImage: value.systemImage,
                            isSelected: model.selectedFrequency == value,
                            action: { model.selectedFrequency = value }
                        )
                    }
                }
            }
            .padding(.top, 14)
        }
    }

    private var actionBlock: some View {
        VStack(spacing: 10) {
            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(step == steps.count - 1 ? "Terminer" : "Continuer", action: advance)
                .primaryAction()
                .disabled(!canAdvance)

            Button("Plus tard", action: onComplete)
                .secondaryAction()
        }
        .padding(.top, 6)
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

    private func advance() {
        guard canAdvance else { return }
        if step == steps.count - 1 {
            guard model.save() else { return }
            onComplete()
            return
        }

        withAnimation(reduceMotion ? nil : .snappy) {
            step += 1
        }
    }
}

private enum OnboardingQuestion: Int, CaseIterable {
    case pass
    case presence
    case frequency

    var title: String {
        switch self {
        case .pass: "Quel titre utilises-tu le plus ?"
        case .presence: "Tu es de passage en Île-de-France ?"
        case .frequency: "À quelle fréquence prends-tu les transports ?"
        }
    }

    var subtitle: String {
        switch self {
        case .pass: "On adaptera les conseils et les raccourcis à tes habitudes."
        case .presence: "Cela nous aide à choisir le bon niveau d’explication."
        case .frequency: "Il n’y a pas de mauvaise réponse."
        }
    }
}

#Preview("Profil de transport") {
    OnboardingProfileView(
        model: OnboardingProfileModel(store: InMemoryOnboardingProfileStore()),
        onComplete: {}
    )
}
