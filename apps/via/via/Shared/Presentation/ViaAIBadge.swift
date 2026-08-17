import SwiftUI

/// The signature that marks a surface as answered by Via's assistant.
struct ViaAIBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
            Text("VIA")
                .tracking(2)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(Color.viaAIAccent)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Via")
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    ViaAIBadge()
        .padding()
}
