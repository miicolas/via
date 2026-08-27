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

  /// The transport modes the criteria narrow to; empty when no mode criterion
  /// is active, in which case every line is shown.
  var transitModes: Set<TransitMode> {
    Set(criteria.compactMap { criterion in
      if case .mode(let mode) = criterion { mode } else { nil }
    })
  }

  var sharedMobilityCriteria: Set<StationMapFilterCriterion> {
    criteria.intersection(Set(StationMapFilterCriterion.sharedMobility))
  }

  var wantsSharedMobility: Bool {
    !sharedMobilityCriteria.isEmpty
  }

  /// The operators the active criteria actually ask for, so a screen can tell
  /// "no vehicles here" from "every source we asked is down". The mode-to-
  /// operator mapping is `SharedMobilityProvider.providers(for:)`; only the
  /// criterion-to-mode step belongs to the filter.
  var requestedSharedMobilityProviders: Set<SharedMobilityProvider> {
    var providers: Set<SharedMobilityProvider> = []
    if contains(.sharedBikes) {
      providers.formUnion(SharedMobilityProvider.providers(for: .bicycle))
    }
    if contains(.sharedScooters) {
      providers.formUnion(SharedMobilityProvider.providers(for: .scooter))
    }
    if contains(.bikeStations) {
      providers.insert(.velib)
    }
    return providers
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
    if let cluster = station.sharedMobilityCluster {
      return criteria.contains(cluster.mode == .bicycle ? .sharedBikes : .sharedScooters)
    }
    if station.sharedMobility != nil {
      return !criteria.isEmpty && criteria.contains { $0.matches(station) }
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
  case sharedBikes
  case sharedScooters
  case bikeStations
  case mode(TransitMode)

  static let facilities: [Self] = [.accessibility, .elevators, .toilets]
  static let sharedMobility: [Self] = [.sharedBikes, .sharedScooters, .bikeStations]
  static let transportModes: [Self] = TransitMode.allCases.map(Self.mode)
  static let allInDisplayOrder = facilities + sharedMobility + transportModes

  var title: String {
    switch self {
    case .accessibility: "PMR"
    case .elevators: "Ascenseurs"
    case .toilets: "Sanitaires"
    case .sharedBikes: "Vélos"
    case .sharedScooters: "Scooters"
    case .bikeStations: "Stations Vélib’"
    case .mode(let mode): mode.displayName
    }
  }

  var sharedMobilityProviders: [SharedMobilityProvider] {
    switch self {
    case .sharedBikes: [.dott, .lime]
    case .sharedScooters: [.dott, .yego]
    case .bikeStations: [.velib]
    default: []
    }
  }

  var systemImage: String {
    switch self {
    case .accessibility: "figure.roll"
    case .elevators: "arrow.up.arrow.down.square"
    case .toilets: "toilet"
    case .sharedBikes: "bicycle"
    case .sharedScooters: "scooter"
    // SF Symbols has no dedicated "station" glyph; the bicycle-in-circle
    // mark reads as a Vélib' station without confusing it with parking.
    case .bikeStations: "bicycle.circle.fill"
    case .mode(let mode): mode.chipSystemImage
    }
  }

  fileprivate func matches(_ station: StationMapItem) -> Bool {
    switch self {
    case .accessibility:
      return station.accessibility != nil
    case .elevators:
      return station.hasElevators
    case .toilets:
      return station.toilets != nil
    case .bikeStations:
      return station.dock != nil
    case .sharedBikes:
      if case .vehicle(let vehicle) = station.sharedMobility {
        return vehicle.mode == .bicycle
      }
      return false
    case .sharedScooters:
      if case .vehicle(let vehicle) = station.sharedMobility {
        return vehicle.mode == .scooter
      }
      return false
    case .mode(let mode):
      return station.modes.contains(mode)
    }
  }
}

// MARK: - Persistence

/// Criteria travel as explicit tokens rather than through a synthesized
/// `Codable`: the wire form has to survive a criterion being renamed, added, or
/// dropped, and a stored set that no longer decodes would take the whole filter
/// down with it.
extension StationMapFilterCriterion {
  var token: String {
    switch self {
    case .accessibility: "accessibility"
    case .elevators: "elevators"
    case .toilets: "toilets"
    case .bikeStations: "bikeStations"
    case .sharedBikes: "sharedBikes"
    case .sharedScooters: "sharedScooters"
    case .mode(let mode): "mode.\(mode.rawValue)"
    }
  }

  /// `nil` for a token this build no longer knows — the criterion is dropped
  /// and the rest of the filter is restored.
  init?(token: String) {
    switch token {
    case "accessibility": self = .accessibility
    case "elevators": self = .elevators
    case "toilets": self = .toilets
    case "bikeStations": self = .bikeStations
    case "sharedBikes": self = .sharedBikes
    case "sharedScooters": self = .sharedScooters
    default:
      guard token.hasPrefix("mode."),
            let mode = TransitMode(rawValue: String(token.dropFirst("mode.".count)))
      else { return nil }
      self = .mode(mode)
    }
  }
}

extension StationMapFilter: Codable {
  private enum CodingKeys: String, CodingKey {
    case criteria
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let tokens = try container.decodeIfPresent([String].self, forKey: .criteria) ?? []
    criteria = Set(tokens.compactMap(StationMapFilterCriterion.init(token:)))
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // Sorted so an unchanged filter encodes to identical bytes.
    try container.encode(criteria.map(\.token).sorted(), forKey: .criteria)
  }
}
