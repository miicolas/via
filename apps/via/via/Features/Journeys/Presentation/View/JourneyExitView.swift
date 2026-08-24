import SwiftUI

struct JourneyExitView: View {
  let exit: JourneyExit
  var isDimmed = false

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "figure.walk.departure")
        .font(.body.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 20)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 3) {
        Text(exitTitle)
          .font(.body.weight(.semibold))
          .foregroundStyle(.primary)

        Text(exit.name)
          .font(.subheadline)
          .foregroundStyle(.secondary)

        if let distance {
          Text("\(distance) jusqu’à destination")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.top, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .opacity(isDimmed ? 0.45 : 1)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private var exitTitle: String {
    if let number = exit.number {
      return "Sortie \(number)"
    }
    return "Sortie recommandée"
  }

  private var distance: String? {
    JourneyFormatting.exitDistance(meters: exit.walkingMeters)
  }

  private var accessibilityLabel: String {
    JourneyFormatting.exitAccessibilityLabel(
      name: exit.name,
      number: exit.number,
      walkingMeters: exit.walkingMeters
    )
  }
}
