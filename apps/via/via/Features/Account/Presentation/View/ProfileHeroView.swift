import SwiftUI

struct ProfileHeroView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.82), .cyan.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                Circle()
                    .fill(.white.opacity(0.96))

                Image(systemName: "person.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.blue.gradient)
            }
            .frame(width: 72, height: 72)
            .shadow(color: .blue.opacity(0.22), radius: 14, y: 6)
        }
        .frame(height: 140)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
