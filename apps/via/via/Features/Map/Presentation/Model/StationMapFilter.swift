import Foundation

/// The criteria that narrow annotations on the map. An empty set means every
/// transit station; shared mobility is opt-in. Multiple criteria use OR semantics.
struct StationMapFilter: Sendable, Equatable {
  var criteria: Set<StationMapFilterCriterion> = []

  var isActive: Bool {
    !criteria.isEmpty
  }

  var activeCount: Int {
    criteria.count
  }

  var activeCriteriaInDisplayOrder: [StationMapFilterCriterion] {
    StationMapFilterCriterion.allInDisplayOrder.filter(criteria.contains)
  }

  func contains(_ criterion: StationMapFilterCriterion) -> Bool {
    criteria.contains(criterion)
  }

  mutating func set(_ criterion: StationMapFilterCriterion, isEnabled: Bool) {
    if isEnabled {
      criteria.insert(criterion)
    } else {
      criteria.remove(criterion)
    }
  }

  func matches(_ station: StationMapItem) -> Bool {
    if station.bikeStation != nil {
      return criteria.contains(.bikeStations)
    }
    return criteria.isEmpty || criteria.contains { $0.matches(station) }
  }

  mutating func reset() {
    criteria.removeAll()
  }
}

enum StationMapFilterCriterion: Sendable, Hashable {
  case accessibility
  case elevators
  case toilets
  case bikeStations
  case mode(TransitMode)

  static let facilities: [Self] = [.accessibility, .elevators, .toilets]
  static let sharedMobility: [Self] = [.bikeStations]
  static let transportModes: [Self] = TransitMode.allCases.map(Self.mode)
  static let allInDisplayOrder = facilities + sharedMobility + transportModes

  var title: String {
    switch self {
    case .accessibility: "PMR"
    case .elevators: "Ascenseurs"
    case .toilets: "Sanitaires"
    case .bikeStations: "Vélib’"
    case .mode(let mode): mode.displayName
    }
  }

  var systemImage: String {
    switch self {
    case .accessibility: "figure.roll"
    case .elevators: "arrow.up.arrow.down.square"
    case .toilets: "toilet"
    case .bikeStations: "bicycle"
    case .mode(let mode): mode.chipSystemImage
    }
  }

  fileprivate func matches(_ station: StationMapItem) -> Bool {
    switch self {
    case .accessibility:
      station.accessibility != nil
    case .elevators:
      station.hasElevators
    case .toilets:
      station.toilets != nil
    case .bikeStations:
      station.bikeStation != nil
    case .mode(let mode):
      station.modes.contains(mode)
    }
  }
}
