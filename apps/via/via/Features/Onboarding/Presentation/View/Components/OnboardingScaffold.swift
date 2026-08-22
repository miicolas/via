import SwiftUI

/// The first run's stage: black ground, one glass panel at the bottom, one
/// chevron in the top corner.
///
/// The presentation, the account step and the profile questions are a single
/// screen as far as the traveller is concerned — they only swap what stands on
/// the stage and what the panel asks for. Holding that chrome here is what
/// keeps the three from drifting apart: a step hands over a stage and a panel,
/// and owns nothing else about the way the screen looks.
struct OnboardingScaffold<Stage: View, Panel: View>: View {
    /// `nil` on the very first screen: there is nowhere to go back to, so the
    /// chevron is absent rather than sitting there dead.
    private let onBack: (() -> Void)?
    private let backHint: String
    /// The blur only earns its keep where the stage runs under the panel — on a
    /// step whose content stops short, it would smear black over black.
    private let showsPanelBackground: Bool

    private let stage: Stage
    private let panel: Panel

    init(
        onBack: (() -> Void)? = nil,
        backHint: String = "Revient à l’étape précédente",
        showsPanelBackground: Bool = true,
        @ViewBuilder stage: () -> Stage,
        @ViewBuilder panel: () -> Panel
    ) {
        self.onBack = onBack
        self.backHint = backHint
        self.showsPanelBackground = showsPanelBackground
        self.stage = stage()
        self.panel = panel()
    }

    /// Measured rather than fixed: the panel grows with its own content — two
    /// buttons on the account step, one on a question — and the stage above has
    /// to know how much room is left to it.
    @State private var panelHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .ignoresSafeArea()

            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 35)
                .padding(.horizontal, 30)
                .padding(.bottom, panelHeight + 10)

            panelContent

            backButton
        }
        .preferredColorScheme(.dark)
    }

    private var panelContent: some View {
        panel
            .padding(.top, 20)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .background {
                variableGlassBlur(15)
            }
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: { newValue in
                panelHeight = newValue
            }
    }

    @ViewBuilder
    private var backButton: some View {
        if let onBack {
            Button("Étape précédente", systemImage: "chevron.left", action: onBack)
                .iconAction()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 15)
                .padding(.top, 5)
                .accessibilityHint(backHint)
        }
    }

    /// A blurred slab bled past its own edges, so the panel fades into the
    /// stage instead of drawing a line across it.
    private func variableGlassBlur(_ radius: CGFloat) -> some View {
        Rectangle()
            .fill(.black.opacity(0.5))
            .glassEffect(.clear, in: .rect)
            .blur(radius: radius)
            .padding([.horizontal, .bottom], -radius * 2)
            .padding(.top, -radius / 2)
            .opacity(showsPanelBackground ? 1 : 0)
            .ignoresSafeArea()
    }
}

#Preview("Socle") {
    OnboardingScaffold(onBack: {}) {
        RoundedRectangle(cornerRadius: 32)
            .fill(.white.opacity(0.1))
    } panel: {
        VStack(spacing: 10) {
            OnboardingHeadline(title: "Un titre", subtitle: "Une phrase sous le titre.", wraps: true)
            OnboardingStepIndicator(count: 3, currentIndex: 1)
            Button("Continuer") {}
                .primaryAction(tint: .blue)
                .padding(.horizontal, 30)
        }
    }
}
