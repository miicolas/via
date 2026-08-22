import Foundation

/// The service level of a whole line, mirroring the API's `condition`:
/// the worst disruption currently active wins.
enum LineCondition: String, Codable, CaseIterable, Sendable, Hashable {
  case normal
  case attention
  case disrupted
  case suspended

  var title: String {
    switch self {
    case .normal: "Service normal"
    case .attention: "Information"
    case .disrupted: "Perturbée"
    case .suspended: "Interrompue"
    }
  }

  var systemImage: String {
    switch self {
    case .normal: "checkmark.circle.fill"
    case .attention: "info.circle.fill"
    case .disrupted: "exclamationmark.triangle.fill"
    case .suspended: "xmark.octagon.fill"
    }
  }

  /// Lower values appear first wherever travellers scan for problems.
  var displayPriority: Int {
    switch self {
    case .suspended: 0
    case .disrupted: 1
    case .attention: 2
    case .normal: 3
    }
  }
}

/// A planned disruption starting within the next seven days.
struct UpcomingClosure: Codable, Sendable, Hashable {
  let beginsAt: Date
  let title: String?
}

struct LineStatus: Identifiable, Sendable, Hashable {
  let route: RouteBadge
  let condition: LineCondition
  /// Title of the worst active disruption; nil when the line runs normally.
  let summary: String?
  let activeCount: Int
  let upcoming: UpcomingClosure?

  var id: RouteID { route.id }

  func matchesSearch(_ query: String) -> Bool {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else { return true }

    let foldingOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    let haystack = [route.shortName, route.mode.displayNameForSearch]
      .joined(separator: " ")
      .folding(options: foldingOptions, locale: Locale.current)
    let foldedQuery = trimmedQuery.folding(options: foldingOptions, locale: Locale.current)

    return
      foldedQuery
      .split(whereSeparator: \.isWhitespace)
      .allSatisfy { haystack.contains(String($0)) }
  }
}

extension TransitMode {
  /// Domain-side copy of the French mode name, so `matchesSearch` stays out
  /// of the view layer ("ligne A", "rer", "métro 4" must all match).
  var displayNameForSearch: String {
    switch self {
    case .metro: "Métro"
    case .rer: "RER"
    case .transilien: "Transilien"
    case .tram: "Tram"
    case .bus: "Bus"
    }
  }
}

/// The Lines tab payload. `unavailable` means the disruptions feed could not
/// be read: lines then all carry `normal` and must read as state-unknown, not
/// healthy.
struct LineStatusBoard: Sendable, Hashable {
  enum Source: String, Codable, Sendable {
    case live
    case unavailable
  }

  let source: Source
  let fetchedAt: Date?
  let lines: [LineStatus]

  static let empty = LineStatusBoard(source: .unavailable, fetchedAt: nil, lines: [])
}
