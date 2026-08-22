import SwiftUI

struct JourneyReminderMinutePicker: View {
  @Binding var selection: JourneyNotificationPreferences.DepartureLeadTime

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let thumbDiameter: CGFloat = 28
  private let trackHeight: CGFloat = 6
  private let tickHeight: CGFloat = 7

  var body: some View {
    VStack(spacing: 20) {
      VStack(spacing: 2) {
        Text("\(selection.rawValue)")
          .font(.system(.largeTitle, design: .rounded, weight: .bold))
          .monospacedDigit()
          .contentTransition(reduceMotion ? .identity : .numericText(value: Double(selection.rawValue)))

        Text("minutes avant le départ")
          .font(.headline)
          .foregroundStyle(.white.opacity(0.82))
      }

      slider
    }
    .padding(22)
    .foregroundStyle(.white)
    .background(
      LinearGradient(
        colors: [Color.accentColor.opacity(0.76), Color.accentColor],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 28, style: .continuous)
    )
    .animation(reduceMotion ? nil : .snappy, value: selection)
    .sensoryFeedback(.selection, trigger: selection)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Délai avant le départ")
    .accessibilityValue("\(selection.rawValue) minutes")
    .accessibilityHint("Balayez vers le haut ou le bas pour modifier le délai")
    .accessibilityAdjustableAction { direction in
      adjustSelection(direction)
    }
  }

  private var slider: some View {
    GeometryReader { geometry in
      let inset = thumbDiameter / 2
      let usableWidth = max(1, geometry.size.width - thumbDiameter)
      let thumbX = inset + progress(for: selection) * usableWidth

      VStack(spacing: 8) {
        ZStack(alignment: .leading) {
          Capsule()
            .fill(.white.opacity(0.26))
            .frame(height: trackHeight)

          Capsule()
            .fill(.white)
            .frame(width: thumbX, height: trackHeight)

          Circle()
            .fill(.white)
            .frame(width: thumbDiameter, height: thumbDiameter)
            .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
            .offset(x: thumbX - inset)
        }
        .frame(height: thumbDiameter)

        ticks(inset: inset, usableWidth: usableWidth)

        labels(inset: inset, usableWidth: usableWidth)
      }
      .frame(height: geometry.size.height, alignment: .top)
      .contentShape(.rect)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            updateSelection(at: value.location.x, inset: inset, usableWidth: usableWidth)
          }
      )
    }
    .frame(height: 74)
  }

  private func ticks(inset: CGFloat, usableWidth: CGFloat) -> some View {
    ZStack(alignment: .leading) {
      ForEach(JourneyNotificationPreferences.DepartureLeadTime.allCases) { leadTime in
        let isSelected = leadTime == selection

        Capsule()
          .fill(.white.opacity(isSelected ? 1 : 0.45))
          .frame(width: 2, height: tickHeight)
          .offset(x: inset + progress(for: leadTime) * usableWidth - 1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: tickHeight)
  }

  private func labels(inset: CGFloat, usableWidth: CGFloat) -> some View {
    ZStack(alignment: .leading) {
      ForEach(JourneyNotificationPreferences.DepartureLeadTime.allCases) { leadTime in
        let isSelected = leadTime == selection

        Text("\(leadTime.rawValue)")
          .font(.caption2.weight(isSelected ? .bold : .medium))
          .monospacedDigit()
          .foregroundStyle(.white.opacity(isSelected ? 1 : 0.62))
          .fixedSize()
          .frame(width: thumbDiameter)
          .offset(x: inset + progress(for: leadTime) * usableWidth - thumbDiameter / 2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func progress(
    for leadTime: JourneyNotificationPreferences.DepartureLeadTime
  ) -> CGFloat {
    let minimum = JourneyNotificationPreferences.DepartureLeadTime.fiveMinutes.rawValue
    let maximum = JourneyNotificationPreferences.DepartureLeadTime.thirtyMinutes.rawValue
    return CGFloat(leadTime.rawValue - minimum) / CGFloat(maximum - minimum)
  }

  private func updateSelection(at x: CGFloat, inset: CGFloat, usableWidth: CGFloat) {
    let position = min(max(x - inset, 0), usableWidth) / usableWidth
    let minimum = JourneyNotificationPreferences.DepartureLeadTime.fiveMinutes.rawValue
    let maximum = JourneyNotificationPreferences.DepartureLeadTime.thirtyMinutes.rawValue
    let rawValue = minimum + Int((position * CGFloat(maximum - minimum) / 5).rounded()) * 5

    if let leadTime = JourneyNotificationPreferences.DepartureLeadTime(rawValue: rawValue),
       leadTime != selection {
      selection = leadTime
    }
  }

  private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
    let options = JourneyNotificationPreferences.DepartureLeadTime.allCases
    guard let index = options.firstIndex(of: selection) else { return }

    switch direction {
    case .increment:
      selection = options[min(index + 1, options.index(before: options.endIndex))]
    case .decrement:
      selection = options[max(index - 1, options.startIndex)]
    @unknown default:
      break
    }
  }
}
