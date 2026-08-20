import SwiftUI

struct AIBadge: View {
    var body: some View {
        Label("Apple Intelligence", systemImage: "sparkles")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.aiAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.aiSurface, in: Capsule())
            .accessibilityElement(children: .combine)
    }
}
