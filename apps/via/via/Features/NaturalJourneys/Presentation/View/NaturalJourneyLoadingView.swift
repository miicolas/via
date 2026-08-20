import SwiftUI

struct NaturalJourneyLoadingView: View {
    let phrase: String

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            Text("Compréhension de la demande…")
                .font(.title3.weight(.semibold))
            Text(phrase)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}
