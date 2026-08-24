import Foundation
import Observation

protocol StationMapFilterPersisting: Sendable {
  func load() -> StationMapFilter
  func save(_ filter: StationMapFilter)
}

struct UserDefaultsStationMapFilterPersistence: StationMapFilterPersisting, @unchecked Sendable {
  private let defaults: UserDefaults
  private let key = "via.map.filter.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> StationMapFilter {
    guard
      let data = defaults.data(forKey: key),
      let filter = try? JSONDecoder().decode(StationMapFilter.self, from: data)
    else { return StationMapFilter() }
    return filter
  }

  func save(_ filter: StationMapFilter) {
    guard let data = try? JSONEncoder().encode(filter) else { return }
    defaults.set(data, forKey: key)
  }
}

final class InMemoryStationMapFilterPersistence: StationMapFilterPersisting, @unchecked Sendable {
  var filter: StationMapFilter

  init(filter: StationMapFilter = StationMapFilter()) {
    self.filter = filter
  }

  func load() -> StationMapFilter { filter }
  func save(_ filter: StationMapFilter) { self.filter = filter }
}

/// The one filter the map, the nearby list and the Stations tab all read.
///
/// It used to live on `NetworkViewModel`, which meant the map could be showing
/// docks while a list built from the same stations was not — and that a filter
/// the traveller set was gone at the next launch. Both follow from there being
/// no single owner, so there is one now, and it remembers.
///
/// Observation covers views; the view models that react outside a body
/// register a callback instead. Nothing unregisters: every consumer lives as
/// long as the store does, and each captures itself weakly.
@MainActor
@Observable
final class StationMapFilterStore {
  var filter: StationMapFilter {
    didSet {
      guard filter != oldValue else { return }
      persistence.save(filter)
      let current = filter
      for observer in observers { observer(current) }
    }
  }

  @ObservationIgnored private let persistence: any StationMapFilterPersisting
  @ObservationIgnored private var observers: [@MainActor (StationMapFilter) -> Void] = []

  init(persistence: any StationMapFilterPersisting = InMemoryStationMapFilterPersistence()) {
    self.persistence = persistence
    filter = persistence.load()
  }

  func onChange(_ body: @escaping @MainActor (StationMapFilter) -> Void) {
    observers.append(body)
  }
}
