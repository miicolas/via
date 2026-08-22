import SwiftUI

struct JourneyBoardingPositionView: View {
  let position: JourneyBoardingPosition
  var isDimmed = false

  var body: some View {
    HStack(spacing: 10) {
      GlassSquareBadge(tint: .accentColor, size: 42) {
        Image(systemName: position.systemImage)
          .font(.system(size: 22, weight: .bold))
      }
      .accessibilityHidden(true)

      Text(position.carLabel)
        .font(.headline.monospacedDigit())

      if let equipmentSymbol {
        Image(systemName: equipmentSymbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .opacity(isDimmed ? 0.45 : 1)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private var equipmentSymbol: String? {
    switch position.equipment {
    case .escalator: "figure.stairs"
    case .lift: "arrow.up.arrow.down.square"
    case .stairs: "stairs"
    case nil: nil
    }
  }

  private var accessibilityLabel: String {
    JourneyFormatting.boardingPositionAccessibilityLabel(position)
  }
}

extension JourneyBoardingPosition {
  var systemImage: String {
    switch zone {
    case .front: "train.side.front.car"
    case .middle: "train.side.middle.car"
    case .rear: "train.side.rear.car"
    }
  }

  var carLabel: String {
    "\(car)/\(carCount)"
  }
}
