import SwiftUI

struct JourneyArrivalView: View {
    let arrival: JourneyArrival
    let onComplete: () -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
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
            .frame(maxWidth: .infinity, minHeight: 260)
        }
        .accessibilityElement(children: .contain)
        .task {
            guard !isVoiceOverEnabled, !dynamicTypeSize.isAccessibilitySize else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}
