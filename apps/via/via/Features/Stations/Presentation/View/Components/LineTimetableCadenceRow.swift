import SwiftUI

/// One rhythm of the line sheet — "toutes les 4 min, de 10:23 à 11:07" — that
/// opens onto the individual times it stands for.
///
/// Folded, it costs one row instead of the twelve it replaces; opened, the times
/// arrive as a grid of hours rather than as twelve live rows, so a traveller
/// checking one departure never pays for a screenful of countdowns.
struct LineTimetableCadenceRow: View {
  let cadence: TimetableCadence

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Button {
        isExpanded.toggle()
      } label: {
        summary
      }
      .buttonStyle(.plain)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(spokenSummary)
      .accessibilityValue(isExpanded ? "Développé" : "Replié")
      .accessibilityHint("Affiche ou masque les horaires de cette plage.")

      if isExpanded {
        times
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 4)
    .animation(reduceMotion ? nil : .snappy, value: isExpanded)
    // Opening the times is the tap the screen barely acknowledges: nothing is
    // kept or turned on, so both directions feel the same.
    .haptic(Haptic.tap, on: isExpanded)
  }

  private var summary: some View {
    HStack(alignment: .center, spacing: 14) {
      Image(systemName: "repeat")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 36, alignment: .center)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text("Toutes les \(cadence.headwayMinutes) min")
          .font(.body.weight(.semibold))
          .foregroundStyle(.primary)

        Text(spanText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Image(systemName: StateSymbol.disclosure(isExpanded: isExpanded))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
        .stateSymbolTransition(value: isExpanded)
        .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
  }

  private var times: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 58), spacing: 8)],
      alignment: .leading,
      spacing: 8
    ) {
      ForEach(cadence.departures) { departure in
        if let departureAt = departure.departureAt {
          Text(Self.timeText(departureAt))
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .padding(.leading, 50)
    .padding(.bottom, 4)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Horaires : \(spokenTimes)")
  }

  private var spanText: String {
    guard let startsAt = cadence.startsAt, let endsAt = cadence.endsAt else {
      return passageCountText
    }
    return "de \(Self.timeText(startsAt)) à \(Self.timeText(endsAt)) · \(passageCountText)"
  }

  private var passageCountText: String {
    "\(cadence.count) passage\(cadence.count == 1 ? "" : "s")"
  }

  private var spokenSummary: String {
    let minutes = cadence.headwayMinutes
    let rhythm = "Toutes les \(minutes) \(minutes == 1 ? "minute" : "minutes")"

    guard let startsAt = cadence.startsAt, let endsAt = cadence.endsAt else {
      return "\(rhythm), \(passageCountText)"
    }

    return "\(rhythm), de \(Self.timeText(startsAt)) à \(Self.timeText(endsAt)), \(passageCountText)"
  }

  /// Read out rather than left as a grid: VoiceOver crossing forty separate
  /// hours is a swipe marathon, and the grid is one fact.
  private var spokenTimes: String {
    cadence.departures
      .compactMap(\.departureAt)
      .map(Self.timeText)
      .joined(separator: ", ")
  }

  private static func timeText(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
  }
}

#Preview {
  let route = RouteBadge(
    id: RouteID(rawValue: "preview:metro:4"),
    shortName: "4",
    mode: .metro,
    colorHex: "#B42C91",
    textColorHex: "#FFFFFF"
  )
  let start = Date.now.addingTimeInterval(15 * 60)

  LineTimetableCadenceRow(
    cadence: TimetableCadence(
      id: "preview",
      departures: (0..<14).map { index in
        StationDeparture(
          route: route,
          destination: "Bagneux",
          departureAt: start.addingTimeInterval(Double(index) * 4 * 60)
        )
      }
    )
  )
  .padding()
}
