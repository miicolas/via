import Foundation
import Observation

/// Owns the complete lifecycle of the station detail presented above the map.
/// Callers select a station; the model handles the immediate placeholder,
/// departure refresh, stale responses, and persisted favorite state.
@MainActor
@Observable
final class SelectedStationModel {
  private(set) var overview: StationOverview?
  private(set) var loadingState: SelectedStationLoadingState = .idle

  @ObservationIgnored private let departuresRepository: any DeparturesRepository
  @ObservationIgnored private let account: AccountModel
  @ObservationIgnored private let locationModel: LocationModel
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private var loadTask: Task<Void, Never>?
  @ObservationIgnored private var selectionGeneration = 0

  init(
    departuresRepository: any DeparturesRepository,
    account: AccountModel,
    locationModel: LocationModel,
    now: @escaping @Sendable () -> Date = { .now }
  ) {
    self.departuresRepository = departuresRepository
    self.account = account
    self.locationModel = locationModel
    self.now = now
  }

  var isFavorite: Bool {
    guard let overview else { return false }
    return account.isFavorite(stationID: overview.id)
  }

  var isNotificationFollowed: Bool {
    guard let overview else { return false }
    return account.isFollowingNotification(topicKind: .station, topicID: overview.id.rawValue)
  }

  /// Opens a station whose current overview is already available, such as
  /// the nearest station displayed in the stations tab.
  func select(_ overview: StationOverview) {
    beginSelection(with: overview, refreshDepartures: true)
  }

  /// Opens a map annotation immediately, then refreshes its departures in
  /// the background without exposing either phase to the map shell.
  func select(_ item: StationMapItem) {
    let placeholder = StationOverview(
      id: item.id,
      name: item.name,
      coordinate: item.coordinate,
      routes: item.routes,
      accessibility: item.accessibility,
      distanceMeters: locationModel.coordinate.map {
        item.coordinate.metersAway(from: $0)
      },
      departures: [],
      departureSource: .unavailable
    )
    beginSelection(with: placeholder, refreshDepartures: true)
  }

  func dismiss() {
    selectionGeneration &+= 1
    loadTask?.cancel()
    loadTask = nil
    overview = nil
    loadingState = .idle
  }

  func retry() {
    guard let overview else { return }
    beginSelection(with: overview, refreshDepartures: true)
  }

  @discardableResult
  func toggleFavorite() -> Bool {
    guard let overview else { return false }
    return account.toggleFavorite(
      stationID: overview.id,
      name: overview.name,
      coordinate: overview.coordinate
    )
  }

  @discardableResult
  func toggleNotificationFollow() -> Bool {
    guard let overview else { return false }
    return account.toggleNotificationAlert(
      topicKind: .station,
      topicID: overview.id.rawValue,
      label: overview.name
    )
  }

  private func beginSelection(
    with initialOverview: StationOverview,
    refreshDepartures: Bool
  ) {
    selectionGeneration &+= 1
    let generation = selectionGeneration
    loadTask?.cancel()
    overview = initialOverview
    loadingState = refreshDepartures ? .loading : .loaded

    guard refreshDepartures else {
      loadTask = nil
      return
    }

    let departuresRepository = self.departuresRepository
    loadTask = Task { [weak self] in
      do {
        let board = try await departuresRepository.board(stationID: initialOverview.id)

        guard let self,
          !Task.isCancelled,
          selectionGeneration == generation,
          overview?.id == initialOverview.id
        else {
          return
        }

        overview = StationOverview(
          id: initialOverview.id,
          name: initialOverview.name,
          coordinate: initialOverview.coordinate,
          routes: initialOverview.routes,
          accessibility: initialOverview.accessibility,
          distanceMeters: initialOverview.distanceMeters,
          departures: StationOverviewBuilder.nextDepartures(
            from: board,
            routes: initialOverview.routes,
            now: now()
          ),
          departureSource: board.source,
          departureFetchedAt: board.fetchedAt,
          peak: board.peak
        )
        loadingState = .loaded
      } catch is CancellationError {
      } catch {
        guard let self,
          selectionGeneration == generation,
          overview?.id == initialOverview.id
        else {
          return
        }
        loadingState = .failed(error.via)
      }
    }
  }
}
