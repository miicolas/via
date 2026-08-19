import SwiftUI

struct OnboardingSlideView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.systemImage)
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 120, height: 120)
                .background(.tint.opacity(0.12), in: .circle)

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.largeTitle.weight(.bold))
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(24)
    }
}
