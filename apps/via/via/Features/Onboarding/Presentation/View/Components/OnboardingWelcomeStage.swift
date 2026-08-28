import SwiftUI

/// A logo-free welcome scene for the onboarding carousel.
struct OnboardingWelcomeStage: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.08, blue: 0.14),
                    Color(red: 0.04, green: 0.24, blue: 0.31),
                    Color(red: 0.02, green: 0.06, blue: 0.12),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "tram.fill")
                        .font(.title2.weight(.semibold))

                    Text("Metyro")
                        .font(.title2.weight(.bold))

                    Spacer()

                    Image(systemName: "location.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.cyan)
                }
                .foregroundStyle(.white)

                Spacer()

                routeIllustration
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Tes trajets, en un coup d’œil")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Les prochaines étapes et les correspondances réunies au même endroit.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(34)
        }
    }

    private var routeIllustration: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width * 0.08, y: proxy.size.height * 0.78))
                    path.addCurve(
                        to: CGPoint(x: proxy.size.width * 0.88, y: proxy.size.height * 0.22),
                        control1: CGPoint(x: proxy.size.width * 0.28, y: proxy.size.height * 0.92),
                        control2: CGPoint(x: proxy.size.width * 0.56, y: proxy.size.height * 0.08)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [.blue, .cyan, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round)
                )

                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .overlay { Circle().fill(.blue).frame(width: 8, height: 8) }
                    .position(x: proxy.size.width * 0.08, y: proxy.size.height * 0.78)

                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .overlay { Circle().fill(.cyan).frame(width: 8, height: 8) }
                    .position(x: proxy.size.width * 0.88, y: proxy.size.height * 0.22)

                Image(systemName: "tram.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(.blue.gradient, in: Circle())
                    .shadow(color: .cyan.opacity(0.5), radius: 24)
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.5)
            }
        }
    }
}
