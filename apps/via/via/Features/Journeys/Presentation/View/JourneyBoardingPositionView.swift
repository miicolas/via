import SwiftUI

struct JourneyBoardingPositionView: View {
  let position: JourneyBoardingPosition
  var isDimmed = false

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: symbol)
        .font(.subheadline.weight(.semibold))

      VStack(alignment: .leading, spacing: 1) {
        Text("Position recommandée")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)

        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
      }

      if let equipmentSymbol {
        Image(systemName: equipmentSymbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .foregroundStyle(.tint)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    .opacity(isDimmed ? 0.45 : 1)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private var symbol: String {
    switch position.zone {
    case .front: "train.side.front.car"
    case .middle: "train.side.middle.car"
    case .rear: "train.side.rear.car"
    }
  }

  private var equipmentSymbol: String? {
    switch position.equipment {
    case .escalator: "figure.stairs"
    case .lift: "arrow.up.arrow.down.square"
    case .stairs: "stairs"
    case nil: nil
    }
  }

  private var title: String {
    "\(zoneName) · voiture \(position.car)/\(position.carCount)"
  }

  private var zoneName: String {
    switch position.zone {
    case .front: "En tête"
    case .middle: "Au milieu"
    case .rear: "En queue"
    }
  }

  var accessibilityLabel: String {
    let purpose = switch position.reason {
    case .exit: "pour la sortie"
    case .transfer: "pour la correspondance"
    }
    let equipment = switch position.equipment {
    case .escalator: ", escalator"
    case .lift: ", ascenseur"
    case .stairs: ", escalier"
    case nil: ""
    }
    return "Position recommandée, montez \(zoneName.lowercased()) du train, voiture "
      + "\(position.car) sur \(position.carCount), \(purpose)\(equipment)"
  }
}
