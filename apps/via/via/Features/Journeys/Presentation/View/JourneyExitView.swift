import SwiftUI

struct JourneyExitView: View {
  let exit: JourneyExit
  var isDimmed = false

  var body: some View {
    HStack(spacing: 10) {
      JourneyExitBadge(number: exit.number)

      VStack(alignment: .leading, spacing: 2) {
        Text(exit.name)
          .font(.subheadline.weight(.semibold))

        if let distance {
          Text(distance)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
    }
    .opacity(isDimmed ? 0.45 : 1)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
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
