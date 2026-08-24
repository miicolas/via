import SwiftUI

/// Compact boarding guidance built only from Apple's train-car SF Symbols.
/// Showing the three native cars together gives the highlighted one useful
/// context: a middle car no longer reads as an unexplained coloured block.
struct JourneyBoardingPositionView: View {
    let route: JourneyRoute
    let position: JourneyBoardingPosition
    var isDimmed = false

    var body: some View {
        HStack(spacing: 14) {
            trainPosition

            VStack(alignment: .leading, spacing: 7) {
                Text(instruction)
                    .font(.headline)

                HStack(spacing: 8) {
                    LineBadgeView(route: route.badge, size: 28)

                    Text("\(route.mode.displayName) \(route.shortName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(height: 1)
        }
        .opacity(isDimmed ? 0.4 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// The three car symbols are designed to compose edge to edge: laid out
    /// with no spacing they read as one coupled train, not three icons.
    private var trainPosition: some View {
        HStack(spacing: 0) {
            ForEach(JourneyBoardingPosition.Zone.displayOrder, id: \.self) { zone in
                VStack(spacing: 2) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 7, weight: .bold))
                        .opacity(zone == position.zone ? 1 : 0)

                    Image(systemName: zone.systemImage)
                        .font(.system(size: 27, weight: .medium))
                        .symbolRenderingMode(.monochrome)

                    Text(zone.shortLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(zone == position.zone ? routeTint : Color.secondary.opacity(0.38))
            }
        }
        .accessibilityHidden(true)
    }

    private var instruction: String {
        return switch position.zone {
        case .front: "Monter à l’avant du train"
        case .middle: "Monter au milieu du train"
        case .rear: "Monter à l’arrière du train"
        }
    }

    private var routeTint: Color {
        Color(transitHex: route.colorHex, fallback: .accentColor)
    }

    private var accessibilityLabel: String {
        let routeLabel = "\(route.mode.displayName) ligne \(route.shortName)"
        return "\(routeLabel), \(JourneyFormatting.boardingPositionAccessibilityLabel(position))"
    }
}

extension JourneyBoardingPosition {
    var systemImage: String {
        zone.systemImage
    }

    var carLabel: String {
        "\(car)/\(carCount)"
    }
}

private extension JourneyBoardingPosition.Zone {
    static let displayOrder: [Self] = [.rear, .middle, .front]

    var systemImage: String {
        switch self {
        case .front: "train.side.front.car"
        case .middle: "train.side.middle.car"
        case .rear: "train.side.rear.car"
        }
    }

    var shortLabel: LocalizedStringKey {
        switch self {
        case .front: "Avant"
        case .middle: "Milieu"
        case .rear: "Arrière"
        }
    }
}

#Preview {
    JourneyBoardingPositionView(
        route: JourneyRoute(
            id: RouteID(rawValue: "preview:A"),
            shortName: "A",
            longName: "RER A",
            mode: .rer,
            colorHex: "#EB2132",
            textColorHex: "#FFFFFF"
        ),
        position: JourneyBoardingPosition(
            car: 4,
            carCount: 8,
            zone: .middle,
            reason: .transfer,
            equipment: .escalator
        )
    )
    .padding()
}
