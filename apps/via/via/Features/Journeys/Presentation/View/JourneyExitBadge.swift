import SwiftUI

/// The same exit marker in the timeline and on the map. The pictogram carries
/// the meaning: a filled colour square holding a bare number reads as a line
/// badge, and an exit is not a line. The signage number rides beside the glyph
/// when there is one, and the whole thing stays small — an exit is a detail of
/// the walk, not a step of the journey.
struct JourneyExitBadge: View {
  let number: Int?
  var height: CGFloat = 24

  private var font: Font {
    .system(size: height * 0.5, weight: .semibold, design: .rounded)
  }

  var body: some View {
    HStack(spacing: height * 0.12) {
      Image(systemName: "figure.walk.departure")
        .font(font)

      if let number {
        Text(number.formatted())
          .font(font.monospacedDigit())
      }
    }
    .foregroundStyle(.primary)
    .padding(.horizontal, height * 0.28)
    .frame(height: height)
    .glassEffect(.regular, in: .capsule)
    .accessibilityHidden(true)
  }
}

#Preview {
  HStack(spacing: 12) {
    JourneyExitBadge(number: 6)
    JourneyExitBadge(number: 12)
    JourneyExitBadge(number: nil)
    JourneyExitBadge(number: 3, height: 28)
  }
  .padding()
}
