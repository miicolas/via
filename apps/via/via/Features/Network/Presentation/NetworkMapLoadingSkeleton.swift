import SwiftUI

struct NetworkMapLoadingSkeleton: View {
    private let roads: [(width: CGFloat, x: CGFloat, y: CGFloat, angle: Double)] = [
        (0.92, 0.38, 0.17, 8),
        (0.76, 0.64, 0.32, -31),
        (0.88, 0.39, 0.52, 16),
        (0.72, 0.58, 0.73, -12),
        (0.64, 0.32, 0.88, 28),
    ]

    private let stations: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.18, 0.22, 20),
        (0.66, 0.28, 24),
        (0.42, 0.48, 18),
        (0.79, 0.57, 21),
        (0.24, 0.75, 22),
        (0.61, 0.84, 18),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(.background.opacity(0.18))
                    .background(.thinMaterial)

                ForEach(Array(roads.enumerated()), id: \.offset) { item in
                    let road = item.element
                    ViaSkeleton(.capsule)
                        .frame(width: proxy.size.width * road.width, height: 8)
                        .rotationEffect(.degrees(road.angle))
                        .position(
                            x: proxy.size.width * road.x,
                            y: proxy.size.height * road.y
                        )
                }

                ForEach(Array(stations.enumerated()), id: \.offset) { item in
                    let station = item.element
                    ViaSkeleton(.circle)
                        .frame(width: station.size, height: station.size)
                        .position(
                            x: proxy.size.width * station.x,
                            y: proxy.size.height * station.y
                        )
                }

                VStack {
                    Spacer()

                    NetworkRefreshPill()
                        .padding(.bottom, 24)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chargement de la carte du réseau…")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
