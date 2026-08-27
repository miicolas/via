import Foundation

/// A run of consecutive passages that share one headway — "toutes les 4 min, de
/// 10:23 à 11:07".
///
/// It exists because a service day at one stop is two to four hundred passages
/// per direction, and nobody reads a metro timetable minute by minute: they read
/// its rhythm, then look up the one departure they need. Printing every minute
/// costs the sheet hundreds of live rows the traveller will never scroll to, and
/// still says less than one sentence naming the cadence.
struct TimetableCadence: Sendable, Hashable, Identifiable {
  let id: String
  let departures: [StationDeparture]

  /// Averaged over the whole run rather than read off its first gap: a run Via
  /// accepts as regular may still drift by up to `LineTimetable.headwayTolerance`
  /// between two passages, and the average is the only figure that stays true at
  /// both ends of it.
  var headwayMinutes: Int {
    guard departures.count > 1,
      let first = departures.first?.departureAt,
      let last = departures.last?.departureAt
    else {
      return 0
    }

    let average = last.timeIntervalSince(first) / Double(departures.count - 1)
    return max(1, Int((average / 60).rounded()))
  }

  var startsAt: Date? { departures.first?.departureAt }
  var endsAt: Date? { departures.last?.departureAt }
  var count: Int { departures.count }
}

/// One line of the line sheet, whatever it happens to be: the name of a
/// direction, one exact passage, or the rhythm behind them.
///
/// Flattening the timetable into a single sequence is what makes it paginable —
/// the sheet renders a window of rows and grows it as the traveller scrolls,
/// without having to know whether the next screenful is still the same direction.
enum LineTimetableRow: Sendable, Hashable, Identifiable {
  case direction(destination: String, count: Int)
  case passage(StationDeparture)
  case cadence(TimetableCadence)

  var id: String {
    switch self {
    case .direction(let destination, _): "direction-\(destination)"
    case .passage(let departure): "passage-\(departure.id)"
    case .cadence(let cadence): "cadence-\(cadence.id)"
    }
  }

  /// A direction names what follows it; the rows under it are the content it
  /// names. Only the latter are separated by a rule.
  var isHeader: Bool {
    if case .direction = self { return true }
    return false
  }
}

/// The complete timetable of one line at one station, as the sheet reads it.
struct LineTimetable: Sendable, Hashable {
  let rows: [LineTimetableRow]
  let departureCount: Int

  static let empty = LineTimetable(rows: [], departureCount: 0)

  var isEmpty: Bool { rows.isEmpty }

  /// Whether anything was folded — the sheet only explains the rhythm rows when
  /// it actually has some.
  var hasCadence: Bool {
    rows.contains { row in
      if case .cadence = row { return true }
      return false
    }
  }
}

extension LineTimetable {
  /// How many passages keep an exact row at the top of a direction before the
  /// rhythm takes over. The next passage is a decision the traveller is making
  /// now — with its countdown, its delay, its live colour; the fourth one is
  /// already a plan, and a plan only needs the cadence.
  static let exactPassageCount = 3

  /// Under three passages there is no rhythm to name — two times printed side
  /// by side are shorter than the sentence describing them.
  static let minimumCadenceCount = 3

  /// How far one gap may sit from the run's headway and still belong to it. A
  /// minute: a timetable alternating 4 and 5 minutes is one cadence to the
  /// traveller, while 4 and 6 minutes are two different services.
  static let headwayTolerance: TimeInterval = 60

  /// Groups a line's remaining passages by direction, then collapses each
  /// direction's tail into the cadences it actually follows.
  static func make(from departures: [StationDeparture]) -> LineTimetable {
    var order: [String] = []
    var grouped: [String: [StationDeparture]] = [:]

    for departure in departures {
      if grouped[departure.destination] == nil {
        order.append(departure.destination)
      }
      grouped[departure.destination, default: []].append(departure)
    }

    let rows = order.flatMap { destination -> [LineTimetableRow] in
      let chronological = StationOverviewBuilder.chronologically(grouped[destination] ?? [])
      return [.direction(destination: destination, count: chronological.count)]
        + passageRows(for: chronological)
    }

    return LineTimetable(rows: rows, departureCount: departures.count)
  }

  /// One direction, already sorted: the immediate passages, then the rest folded
  /// into cadences.
  private static func passageRows(for chronological: [StationDeparture]) -> [LineTimetableRow] {
    var rows: [LineTimetableRow] = chronological
      .prefix(exactPassageCount)
      .map(LineTimetableRow.passage)
    var pending: [StationDeparture] = []

    for departure in chronological.dropFirst(exactPassageCount) {
      // A cancelled, unserved or timeless passage is the exception no rhythm can
      // absorb: it keeps its own row, and the runs on either side of it stay
      // apart rather than closing over it as if it ran.
      guard departure.isBoardable else {
        rows.append(contentsOf: cadenceRows(for: pending))
        pending = []
        rows.append(.passage(departure))
        continue
      }
      pending.append(departure)
    }

    rows.append(contentsOf: cadenceRows(for: pending))
    return rows
  }

  /// Splits one uninterrupted run of boardable passages wherever its headway
  /// changes, and prints whatever is too short to be a cadence as exact rows.
  private static func cadenceRows(for run: [StationDeparture]) -> [LineTimetableRow] {
    var rows: [LineTimetableRow] = []
    var current: [StationDeparture] = []
    var headway: TimeInterval?

    func flush() {
      defer {
        current = []
        headway = nil
      }

      guard current.count >= minimumCadenceCount, headway != nil, let first = current.first else {
        rows.append(contentsOf: current.map(LineTimetableRow.passage))
        return
      }

      rows.append(
        .cadence(
          TimetableCadence(
            id: "\(first.id)-\(current.count)",
            departures: current
          )
        )
      )
    }

    for departure in run {
      guard let previous = current.last,
        let previousAt = previous.departureAt,
        let departureAt = departure.departureAt
      else {
        flush()
        current = [departure]
        continue
      }

      let gap = departureAt.timeIntervalSince(previousAt)

      guard let currentHeadway = headway else {
        headway = gap
        current.append(departure)
        continue
      }

      if abs(gap - currentHeadway) <= headwayTolerance {
        current.append(departure)
      } else {
        flush()
        current = [departure]
      }
    }

    flush()
    return rows
  }
}
