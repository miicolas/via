import SwiftUI

struct JourneyReminderMinutePicker: View {
  typealias LeadTime = JourneyNotificationPreferences.DepartureLeadTime

  @Binding var selection: LeadTime

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

      minuteScrubber
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
    // Triggered off the value, so a lead time restored from storage used to
    // buzz a sheet nobody had scrolled yet; `haptic` waits for the screen.
    .haptic(Haptic.selection, on: selection)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Délai avant le départ")
    .accessibilityValue("\(selection.rawValue) minutes")
    .accessibilityHint("Balayez vers le haut ou le bas pour modifier le délai")
    .accessibilityAdjustableAction { direction in
      adjustSelection(direction)
    }
  }

  private var minuteScrubber: some View {
    GeometryReader { geometry in
      HStack(spacing: 6) {
        ForEach(LeadTime.allCases) { leadTime in
          let isSelected = leadTime == selection

          Text("\(leadTime.rawValue)")
            .font(.headline.weight(isSelected ? .bold : .medium))
            .monospacedDigit()
            .foregroundStyle(isSelected ? Color.accentColor : .white.opacity(0.68))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
              if isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .fill(.white)
                  .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
              }
            }
        }
      }
      .contentShape(.rect)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            updateSelection(at: value.location.x, width: geometry.size.width)
          }
      )
    }
    .frame(height: 48)
  }

  private func updateSelection(at x: CGFloat, width: CGFloat) {
    guard width > 0 else { return }
    let progress = min(max(x / width, 0), 0.999)
    let options = LeadTime.allCases
    let index = min(Int(progress * CGFloat(options.count)), options.count - 1)
    let leadTime = options[index]
    guard leadTime != selection else { return }
    selection = leadTime
  }

  private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
    let options = LeadTime.allCases
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
