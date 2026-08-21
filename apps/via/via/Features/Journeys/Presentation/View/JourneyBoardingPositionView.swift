import SwiftUI

/// Where to stand on the platform before the train arrives.
///
/// The zone leads and the carriage number follows, in that order on purpose: a
/// short trainset can make "voiture 5 sur 8" wrong, while "en queue" stays true.
/// The train glyph is oriented like the advice — front, middle or rear car lit —
/// so the row reads before the words do.
struct JourneyBoardingPositionView: View {
    let position: JourneyBoardingPosition
    var isDimmed = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.medium))
            if let equipmentSymbol {
                Image(systemName: equipmentSymbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.secondary)
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

    /// Same vocabulary as the `elevatorsUnavailable` / `escalatorUnavailable`
    /// report categories, so one glyph never means two things across the app.
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
        return "Montez \(zoneName.lowercased()) du train, voiture \(position.car) sur "
            + "\(position.carCount), \(purpose)\(equipment)"
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        JourneyBoardingPositionView(
            position: JourneyBoardingPosition(
                car: 5,
                carCount: 5,
                zone: .rear,
                reason: .exit,
                equipment: nil
            )
        )
        JourneyBoardingPositionView(
            position: JourneyBoardingPosition(
                car: 4,
                carCount: 8,
                zone: .middle,
                reason: .transfer,
                equipment: .lift
            )
        )
        JourneyBoardingPositionView(
            position: JourneyBoardingPosition(
                car: 1,
                carCount: 5,
                zone: .front,
                reason: .exit,
                equipment: .escalator
            ),
            isDimmed: true
        )
    }
    .padding()
}
