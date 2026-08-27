import SwiftUI

/// The timetable of one line at one station, drawn a screenful at a time.
///
/// A full service day is hundreds of passages. Even folded into cadences the
/// list stays long enough that building it in one pass costs a visible freeze on
/// open, so the view holds a window over the rows and grows it as the traveller
/// scrolls: the sheet opens on what fits, and the rest arrives under the finger.
struct StationLineTimetableView: View {
  let route: RouteBadge
  let timetable: LineTimetable
  let source: DepartureBoard.Source

  @State private var visibleRowCount = TimetablePage.first

  var body: some View {
    LazyVStack(alignment: .leading, spacing: 0) {
      ForEach(visibleRows) { visible in
        VStack(alignment: .leading, spacing: 0) {
          // A direction names what comes under it, so it is set apart by air;
          // two passages of the same direction are set apart by a rule.
          if visible.hasRuleAbove {
            Divider()
              .padding(.leading, 50)
          }

          content(for: visible.row)
            .padding(.top, visible.hasAirAbove ? 20 : 0)
        }
      }

      if visibleRowCount < timetable.rows.count {
        // The identity moves with the window: a sentinel that kept its own would
        // only ever appear once, and the timetable would stop growing after the
        // page that first revealed it.
        LoadingStatus(label: "Chargement des horaires…")
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .id(visibleRowCount)
          .onAppear {
            visibleRowCount = min(
              timetable.rows.count,
              visibleRowCount + TimetablePage.next
            )
          }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: .rect(cornerRadius: 20))
    .onChange(of: timetable) { _, _ in
      visibleRowCount = TimetablePage.first
    }
  }

  private var visibleRows: [VisibleRow] {
    timetable.rows
      .prefix(visibleRowCount)
      .enumerated()
      .map { index, row in
        VisibleRow(
          row: row,
          hasRuleAbove: index > 0 && !row.isHeader && !timetable.rows[index - 1].isHeader,
          hasAirAbove: index > 0 && row.isHeader
        )
      }
  }

  @ViewBuilder
  private func content(for row: LineTimetableRow) -> some View {
    switch row {
    case .direction(let destination, let count):
      directionHeader(destination: destination, count: count)
    case .passage(let departure):
      DepartureLineRow(route: route, departure: departure, source: source)
    case .cadence(let cadence):
      LineTimetableCadenceRow(cadence: cadence)
    }
  }

  private func directionHeader(destination: String, count: Int) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: "arrow.forward")
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text(destination)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      Spacer(minLength: 8)

      Text(Self.passageCountText(count))
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
    .padding(.bottom, 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Direction \(destination), \(Self.passageCountText(count))")
  }

  private static func passageCountText(_ count: Int) -> String {
    "\(count) passage\(count == 1 ? "" : "s")"
  }
}

/// One row of the visible window, with what separates it from the row above
/// resolved once instead of being looked up again for every redraw.
private struct VisibleRow: Identifiable {
  let row: LineTimetableRow
  let hasRuleAbove: Bool
  let hasAirAbove: Bool

  var id: String { row.id }
}

/// How much of the timetable is built at once. The first window fills more than
/// a screen so the sheet never opens on a sentinel, and each following one is
/// small enough to build between two frames.
private enum TimetablePage {
  static let first = 18
  static let next = 12
}
