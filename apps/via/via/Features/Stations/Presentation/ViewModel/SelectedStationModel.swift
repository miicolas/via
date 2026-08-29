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
  private(set) var liveStatus: StationLiveStatus?
  private(set) var liveStatusError: ViaError?
  private(set) var pendingRecoveryCategory: ReportCategory?
  private(set) var crowding: StationCrowding?
  /// `true` once the profile answered, even empty or failed — `nil` crowding
  /// then means "no profile", so the section hides instead of skeletoning.
  private(set) var isCrowdingLoaded = false
  /// State for the second sheet opened from one line in the station detail.
  /// It deliberately lives beside the station selection so both sheets share
  /// the same station generation and cannot show an old line after a reselection.
  private(set) var lineScheduleRoute: RouteBadge?
  private(set) var lineScheduleDepartures: [StationDeparture] = []
  /// The same passages, grouped by direction and folded into their cadences.
  /// Derived once here rather than in the sheet's `body`: the sheet redraws on
  /// every countdown tick and on every page it appends, and a service day is
  /// several hundred passages to walk each time.
  private(set) var lineScheduleTimetable: LineTimetable = .empty
  private(set) var lineScheduleSource: DepartureBoard.Source = .unavailable
  private(set) var lineScheduleFetchedAt: Date?
  private(set) var lineScheduleLoadingState: SelectedStationLoadingState = .idle

  @ObservationIgnored private let departuresRepository: any DeparturesRepository
  @ObservationIgnored private let crowdingRepository: any StationCrowdingRepository
  @ObservationIgnored private let reportRepository: any ReportRepository
  @ObservationIgnored private let account: AccountModel
  @ObservationIgnored private let locationModel: LocationModel
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private var loadTask: Task<Void, Never>?
  @ObservationIgnored private var crowdingTask: Task<Void, Never>?
  @ObservationIgnored private var lineScheduleTask: Task<Void, Never>?
  @ObservationIgnored private var selectionGeneration = 0

  init(
    departuresRepository: any DeparturesRepository,
    crowdingRepository: any StationCrowdingRepository,
    reportRepository: any ReportRepository,
    account: AccountModel,
    locationModel: LocationModel,
    now: @escaping @Sendable () -> Date = { .now }
  ) {
    self.departuresRepository = departuresRepository
    self.crowdingRepository = crowdingRepository
    self.reportRepository = reportRepository
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
      toilets: item.toilets,
      fountains: item.fountains,
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
    crowdingTask?.cancel()
    crowdingTask = nil
    resetLineSchedule()
    overview = nil
    loadingState = .idle
    liveStatus = nil
    liveStatusError = nil
    pendingRecoveryCategory = nil
    crowding = nil
    isCrowdingLoaded = false
  }

  func retry() {
    guard let overview else { return }
    beginSelection(with: overview, refreshDepartures: true)
  }

  /// Opens the dedicated line sheet and loads the complete remaining service
  /// day for that line. The station overview keeps its compact next-passage
  /// rows, while this request is allowed to be deeper because the user asked
  /// for a specific line's timetable.
  func selectLine(_ route: RouteBadge) {
    guard let overview,
          overview.routes.contains(where: { $0.id == route.id })
    else { return }

    lineScheduleTask?.cancel()
    let generation = selectionGeneration
    let stationID = overview.id
    let repository = departuresRepository
    let nowProvider = now
    lineScheduleRoute = route
    lineScheduleDepartures = []
    lineScheduleTimetable = .empty
    lineScheduleSource = .unavailable
    lineScheduleFetchedAt = nil
    lineScheduleLoadingState = .loading

    lineScheduleTask = Task { [weak self] in
      do {
        let board = try await repository.board(stationID: stationID, routeID: route.id)

        guard let self,
          !Task.isCancelled,
          selectionGeneration == generation,
          self.overview?.id == stationID,
          lineScheduleRoute?.id == route.id
        else {
          return
        }

        lineScheduleDepartures = StationOverviewBuilder.chronologically(
          StationOverviewBuilder.departureBoard(
            from: board,
            routes: [route],
            now: nowProvider()
          )
        )
        lineScheduleTimetable = LineTimetable.make(from: lineScheduleDepartures)
        lineScheduleSource = board.source
        lineScheduleFetchedAt = board.fetchedAt
        lineScheduleLoadingState = .loaded
      } catch is CancellationError {
      } catch {
        guard let self,
          selectionGeneration == generation,
          self.overview?.id == stationID,
          lineScheduleRoute?.id == route.id
        else {
          return
        }
        lineScheduleLoadingState = .failed(error.via)
      }
    }
  }

  func retryLineSchedule() {
    guard let lineScheduleRoute else { return }
    selectLine(lineScheduleRoute)
  }

  /// Called when the dedicated line sheet closes or the station changes.
  func clearLineSchedule() {
    resetLineSchedule()
  }

  /// Called from the visible detail sheet task. SwiftUI cancellation on dismiss,
  /// station change, or inactive scene is the only lifetime this loop has.
  func observeLiveStatusWhileVisible() async {
    guard let stationID = overview?.id else { return }
    var retrySeconds = 30
    while !Task.isCancelled, overview?.id == stationID {
      do {
        let status = try await reportRepository.stationStatus(
          stationID: stationID,
          lineID: nil,
          vehicleID: nil
        )
        try Task.checkCancellation()
        guard overview?.id == stationID else { return }
        liveStatus = status
        liveStatusError = nil
        retrySeconds = 30
      } catch is CancellationError {
        return
      } catch {
        guard overview?.id == stationID else { return }
        discardExpiredLiveStatus()
        liveStatusError = error.via
        retrySeconds = min(max(30, retrySeconds * 2), 300)
      }

      do {
        try await Task.sleep(for: .seconds(retrySeconds))
      } catch {
        return
      }
    }
  }

  func reportRecovery(for category: ReportCategory) {
    guard pendingRecoveryCategory == nil, let overview else { return }
    pendingRecoveryCategory = category
    let stationID = overview.id
    let submission = ReportSubmission(
      category: category,
      value: .resolved,
      context: ReportContext(
        coordinate: overview.coordinate,
        station: ReportStation(
          id: overview.id,
          name: overview.name,
          coordinate: overview.coordinate,
          routes: overview.routes
        )
      ),
      submittedAt: now()
    )
    let repository = reportRepository
    Task { [weak self, repository] in
      do {
        let status = try await repository.submit(submission)
        guard let self, self.overview?.id == stationID else { return }
        self.liveStatus = status
        self.liveStatusError = nil
        self.pendingRecoveryCategory = nil
      } catch is CancellationError {
      } catch {
        guard let self, self.overview?.id == stationID else { return }
        self.pendingRecoveryCategory = nil
        self.liveStatusError = error.via
      }
    }
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
    crowdingTask?.cancel()
    resetLineSchedule()
    overview = initialOverview
    liveStatus = nil
    liveStatusError = nil
    pendingRecoveryCategory = nil
    crowding = nil
    isCrowdingLoaded = false
    loadingState = refreshDepartures ? .loading : .loaded
    loadCrowding(for: initialOverview.id, generation: generation)

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

        let loadedAt = now()
        overview = StationOverview(
          id: initialOverview.id,
          name: initialOverview.name,
          coordinate: initialOverview.coordinate,
          routes: initialOverview.routes,
          accessibility: initialOverview.accessibility,
          toilets: initialOverview.toilets,
          fountains: initialOverview.fountains,
          distanceMeters: initialOverview.distanceMeters,
          departures: StationOverviewBuilder.nextDepartures(
            from: board,
            routes: initialOverview.routes,
            now: loadedAt
          ),
          departureSource: board.source,
          departureFetchedAt: board.fetchedAt,
          peak: board.peak,
          elevators: board.elevators,
          departureBoard: StationOverviewBuilder.departureBoard(
            from: board,
            routes: initialOverview.routes,
            now: loadedAt
          )
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

  /// The habitual profile is supplementary and quarterly-stable, so it loads
  /// once per selection, outside the departures lifecycle, and fails silently:
  /// an unreachable profile just means no chart, never an error banner.
  private func loadCrowding(for stationID: StationID, generation: Int) {
    let crowdingRepository = self.crowdingRepository
    crowdingTask = Task { [weak self] in
      let crowding = try? await crowdingRepository.crowding(stationID: stationID)
      guard let self,
        !Task.isCancelled,
        selectionGeneration == generation,
        self.overview?.id == stationID
      else {
        return
      }
      self.crowding = crowding
      isCrowdingLoaded = true
    }
  }

  private func resetLineSchedule() {
    lineScheduleTask?.cancel()
    lineScheduleTask = nil
    lineScheduleRoute = nil
    lineScheduleDepartures = []
    lineScheduleTimetable = .empty
    lineScheduleSource = .unavailable
    lineScheduleFetchedAt = nil
    lineScheduleLoadingState = .idle
  }

  private func discardExpiredLiveStatus() {
    guard let liveStatus, !liveStatus.hasActiveContent(at: now()) else { return }
    self.liveStatus = nil
  }
}
