import Foundation

/// The one-glance verdict at the top of the Lines tab, derived once from the
/// lines actually on screen — the wording says "affichées", so a filtered
/// board must not be summarised by the lines it hides.
struct LineNetworkSummary: Sendable, Equatable {
  var leadingCondition: LineCondition
  var affectedCount: Int
  var normalCount: Int

  init(lines: [LineStatus]) {
    leadingCondition =
      lines.min {
        $0.condition.displayPriority < $1.condition.displayPriority
      }?.condition ?? .normal
    affectedCount = lines.count { $0.condition != .normal }
    normalCount = lines.count - affectedCount
  }

  var headline: String {
    switch affectedCount {
    case 0: "Réseau fluide"
    case 1: "1 ligne à surveiller"
    default: "\(affectedCount) lignes à surveiller"
    }
  }

  var detail: String {
    if affectedCount == 0 {
      return "Toutes les lignes affichées circulent normalement."
    }
    switch normalCount {
    case 0: return "Chaque ligne affichée rencontre une perturbation."
    case 1: return "1 autre ligne circule normalement."
    default: return "\(normalCount) autres lignes circulent normalement."
    }
  }

  /// What the headline still needs once it sits on a single status line, which
  /// is the count it does not already carry — and nothing at all when the
  /// headline is the whole verdict.
  var trailingDetail: String? {
    guard affectedCount > 0, normalCount > 0 else { return nil }
    return normalCount == 1 ? "1 normale" : "\(normalCount) normales"
  }
}
