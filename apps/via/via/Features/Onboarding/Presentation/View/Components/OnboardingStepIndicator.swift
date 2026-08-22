import SwiftUI

/// Where the traveller stands in a first-run sequence: one bead per step, the
/// current one stretched.
///
/// The presentation and the questions both count their steps this way rather
/// than one of them wearing a progress bar — two shapes for the same fact would
/// read as two different flows.
struct OnboardingStepIndicator: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                let isActive = currentIndex == index

                Capsule()
                    .fill(.white.opacity(isActive ? 1 : 0.4))
                    .frame(width: isActive ? 25 : 6, height: 6)
            }
        }
        .padding(.bottom, 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Étape \(currentIndex + 1) sur \(count)")
    }
}

#Preview("Étapes") {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingStepIndicator(count: 6, currentIndex: 2)
    }
}
