import SwiftUI

/// A street-level recommended exit. The number is the useful map label; the
/// glass square keeps it distinct from circular stations and route beads.
struct JourneyExitAnnotationView: View {
  let exit: JourneyMapExit
  var isDimmed = false

  var body: some View {
    JourneyExitBadge(number: exit.number, size: 44)
      .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
      .opacity(isDimmed ? 0.4 : 1)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(exit.accessibilityLabel)
  }
}

#Preview {
  JourneyExitAnnotationView(
    exit: JourneyMapExit(
      id: "preview:exit",
      name: "boulevard Henri IV",
      number: 6,
      coordinate: GeoCoordinate(latitude: 48.853, longitude: 2.369),
      walkingMeters: 50,
      sectionIndex: 0
    )
  )
  .padding()
}
