import SwiftUI

/// The two lines every first-run step leads with: one title, one sentence.
///
/// The wording changes from step to step, the type never does — that sameness
/// is most of what makes the presentation, the account step and the questions
/// read as one screen.
struct OnboardingHeadline: View {
    let title: String
    let subtitle: String
    /// The carousel's panel is the same height on every page, so its title has
    /// to hold one line. A step that sizes to its own text lets both wrap.
    var wraps = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title2.weight(.semibold))
                .lineLimit(wraps ? nil : titleLineLimit)
                .minimumScaleFactor(wraps ? 1 : 0.8)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: wraps)
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.callout)
                .lineLimit(wraps ? nil : subtitleLineLimit)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: wraps)
                .foregroundStyle(.white.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
    }

    private var titleLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }

    private var subtitleLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 3 : 2
    }
}

#Preview("Titre") {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingHeadline(
            title: "Garde tes trajets avec toi",
            subtitle: "Connecte-toi avec Apple pour retrouver tes favoris sur tous tes appareils.",
            wraps: true
        )
        .padding(30)
    }
}
