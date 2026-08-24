import Foundation
import OSLog

/// The tiled fetch-and-merge every viewport payload needs, written once.
///
/// Stations and Vélib' docks cover the same tiles but age at completely
/// different rates, so they are two caches rather than two branches: the only
/// thing that varies is how long a tile stands (`freshness`), how it is
/// fetched, and how overlapping tiles are merged into one answer.
///
/// A tile is fetched at most once at a time however many viewports want it,
/// and a failure puts that tile — not the whole map — on a cooldown, so a
/// permanently failing tile cannot be retried on every gesture.
actor ViewportTileCache<Value: Sendable> {
    /// Above this many visible tiles the viewport is zoomed out past the
    /// station threshold, so warming neighbours would be wasted work.
    private static var prefetchableVisibleTileCount: Int { 9 }
    private static var prefetchTileLimit: Int { 16 }

    /// `nil` when the payload is reference data and a fetched tile stands for
    /// the whole session. Vélib' passes a real window.
    private let freshness: Duration?
    private let retryCooldown: Duration
    private let fetch: @Sendable (GeoBounds) async throws -> Value
    private let merge: @Sendable ([Value]) -> Value
    private let empty: Value
    private let clock = ContinuousClock()

    private var cached: [ViewportTile: (value: Value, loadedAt: ContinuousClock.Instant)] = [:]
    private var failedAt: [ViewportTile: ContinuousClock.Instant] = [:]
    private var inFlight: [ViewportTile: Task<Void, Never>] = [:]
    private var lastAssembly: (tiles: Set<ViewportTile>, value: Value)?

    init(
        freshness: Duration?,
        retryCooldown: Duration = .seconds(120),
        empty: Value,
        fetch: @escaping @Sendable (GeoBounds) async throws -> Value,
        merge: @escaping @Sendable ([Value]) -> Value
    ) {
        self.freshness = freshness
        self.retryCooldown = retryCooldown
        self.empty = empty
        self.fetch = fetch
        self.merge = merge
    }

    func value(in bounds: GeoBounds) async throws -> Value {
        let visibleTiles = ViewportTile.covering(bounds)
        guard !visibleTiles.isEmpty else { return empty }

        let fetchable = visibleTiles.filter { needsRefresh($0) && !isCoolingDown($0) }
        if fetchable.isEmpty, let last = lastAssembly, last.tiles == visibleTiles {
            prefetchNeighbours(of: visibleTiles)
            return last.value
        }

        for task in fetchable.map({ tileTask($0) }) {
            await task.value
        }
        try Task.checkCancellation()

        let value = merge(visibleTiles.compactMap { cached[$0]?.value })
        lastAssembly = (visibleTiles, value)
        prefetchNeighbours(of: visibleTiles)
        return value
    }

    /// One shared fetch per tile: concurrent viewports (the map and the
    /// nearest-station flow overlap constantly) await the same task, and a
    /// caller's cancellation doesn't abort a fetch someone else may still cache.
    private func tileTask(
        _ tile: ViewportTile,
        priority: TaskPriority? = nil
    ) -> Task<Void, Never> {
        if let existing = inFlight[tile] { return existing }
        let task = Task(priority: priority) {
            defer { inFlight[tile] = nil }
            do {
                guard tile.bounds.isValid else {
                    throw ViaError.invalidRequest("viewport")
                }
                cached[tile] = (try await fetch(tile.bounds), clock.now)
                failedAt[tile] = nil
            } catch is CancellationError {
            } catch {
                failedAt[tile] = clock.now
                AppLog.network.error(
                    "Viewport tile failed: \(String(describing: error), privacy: .private(mask: .hash))"
                )
            }
        }
        inFlight[tile] = task
        return task
    }

    private func isCoolingDown(_ tile: ViewportTile) -> Bool {
        guard let failed = failedAt[tile] else { return false }
        if clock.now - failed < retryCooldown { return true }
        failedAt[tile] = nil
        return false
    }

    private func needsRefresh(_ tile: ViewportTile) -> Bool {
        guard let cached = cached[tile] else { return true }
        guard let freshness else { return false }
        return clock.now - cached.loadedAt >= freshness
    }

    /// Warms the ring of tiles around the viewport at background priority, so
    /// the next pan lands on cached data instead of a request. Only *missing*
    /// tiles are warmed: re-warming a merely stale one would refetch the whole
    /// ring every freshness window for a pan that may never come.
    private func prefetchNeighbours(of visibleTiles: Set<ViewportTile>) {
        guard !visibleTiles.isEmpty,
              visibleTiles.count <= Self.prefetchableVisibleTileCount else { return }

        var ring: Set<ViewportTile> = []
        for tile in visibleTiles {
            for latitudeOffset in -1...1 {
                for longitudeOffset in -1...1 {
                    ring.insert(ViewportTile(
                        latitudeIndex: tile.latitudeIndex + latitudeOffset,
                        longitudeIndex: tile.longitudeIndex + longitudeOffset
                    ))
                }
            }
        }

        let candidates = ring.subtracting(visibleTiles).filter {
            cached[$0] == nil && inFlight[$0] == nil && !isCoolingDown($0)
        }
        for tile in candidates.prefix(Self.prefetchTileLimit) {
            _ = tileTask(tile, priority: .utility)
        }
    }
}
