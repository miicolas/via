import Foundation
import Observation

@MainActor
@Observable
final class LinesViewModel {
    private(set) var board: Loadable<LineStatusBoard> = .idle
    /// Lines the backend matched for the current query — how bus lines,
    /// absent from the permanent rail catalogue, enter the tab.
    private(set) var remoteMatches: [LineStatus] = []
    var searchText: String = ""

    @ObservationIgnored private let repository: any LineStatusRepository
    @ObservationIgnored private var hasStarted = false

    init(repository: any LineStatusRepository) {
        self.repository = repository
    }

    /// Keeps the statuses fresh while the tab is visible. The view owns the
    /// surrounding task, so leaving the tab cancels the loop automatically.
    func runAutomaticRefresh(every interval: Duration = .seconds(60)) async {
        await loadIfNeeded()

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    func loadIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true
        await refresh()
    }

    func refresh() async {
        board = .loading(previous: board.value)
        do {
            board = .loaded(try await repository.statuses())
        } catch is CancellationError {
            board = .failed(.transport, previous: board.value)
        } catch {
            board = .failed(error.via, previous: board.value)
        }
    }

    /// Debounced by the view through `.task(id: searchText)`.
    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            remoteMatches = []
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(250))
            let response = try await repository.searchLines(query: trimmed)
            guard !Task.isCancelled, searchText == query else { return }
            remoteMatches = response.lines
        } catch {
            guard !Task.isCancelled else { return }
            remoteMatches = []
        }
    }

    /// The permanent rail catalogue, one section per mode in display order,
    /// narrowed by the search text.
    var sections: [(mode: TransitMode, lines: [LineStatus])] {
        let lines = (board.value?.lines ?? []).filter { $0.matchesSearch(searchText) }
        let byMode = Dictionary(grouping: lines, by: { $0.route.mode })
        return TransitMode.allCases.compactMap { mode in
            guard let lines = byMode[mode], !lines.isEmpty else { return nil }
            return (mode: mode, lines: lines)
        }
    }

    /// Search results the catalogue does not already show — buses, mostly.
    var extraSearchResults: [LineStatus] {
        let knownIDs = Set((board.value?.lines ?? []).map(\.id))
        return remoteMatches.filter { !knownIDs.contains($0.id) }
    }

    /// Lines with a planned closure, grouped by the day it starts.
    var upcomingByDay: [(day: Date, lines: [LineStatus])] {
        let calendar = Calendar.current
        let upcoming = (board.value?.lines ?? []).filter { $0.upcoming != nil }
        let byDay = Dictionary(grouping: upcoming) { line in
            calendar.startOfDay(for: line.upcoming!.beginsAt)
        }
        return byDay
            .map { (day: $0.key, lines: $0.value.sorted { lhs, rhs in
                (lhs.upcoming?.beginsAt ?? .distantFuture) < (rhs.upcoming?.beginsAt ?? .distantFuture)
            }) }
            .sorted { $0.day < $1.day }
    }
}
