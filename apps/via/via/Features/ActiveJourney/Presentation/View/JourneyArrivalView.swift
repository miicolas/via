import SwiftUI

struct JourneyArrivalView: View {
    let arrival: JourneyArrival
    let isLargeScreen: Bool
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("Vous êtes arrivé")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text(arrival.destinationName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Terminer", action: onComplete)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(300)])
        .presentationCornerRadius(isLargeScreen ? 45 : nil)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled()
        .accessibilityElement(children: .contain)
        .task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}
