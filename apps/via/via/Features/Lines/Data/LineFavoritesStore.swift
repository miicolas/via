import Foundation

/// Persists the lines the traveller chose for quick access.
///
/// Line favorites are intentionally separate from notification subscriptions:
/// saving a line never opts the traveller into alerts. The account wire format
/// currently has no line-favorite field, so this device-local store keeps the
/// preference available without changing the account synchronization contract.
@MainActor
final class LineFavoritesStore {
  private static let key = "via.favorite-lines.v1"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> [RouteID] {
    var seen = Set<RouteID>()
    return (defaults.stringArray(forKey: Self.key) ?? []).compactMap { rawValue in
      let routeID = RouteID(rawValue: rawValue)
      return seen.insert(routeID).inserted ? routeID : nil
    }
  }

  func save(_ routeIDs: [RouteID]) {
    defaults.set(routeIDs.map(\.rawValue), forKey: Self.key)
  }
}
