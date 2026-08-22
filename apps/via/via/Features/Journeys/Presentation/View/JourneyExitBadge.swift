import SwiftUI

/// The same numbered glass square identifies an exit in the timeline and on
/// the map. When signage has no number, the departure glyph remains explicit.
struct JourneyExitBadge: View {
  let number: Int?
  var size: CGFloat = 42

  var body: some View {
    GlassSquareBadge(tint: .green, size: size) {
      if let number {
        Text(number.formatted())
          .font(.system(size: size * 0.43, weight: .bold, design: .rounded).monospacedDigit())
      } else {
        Image(systemName: "figure.walk.departure")
          .font(.system(size: size * 0.43, weight: .bold))
      }
    }
    .accessibilityHidden(true)
  }
}

#Preview {
  HStack(spacing: 12) {
    JourneyExitBadge(number: 6)
    JourneyExitBadge(number: nil)
  }
  .padding()
}
