import Foundation
import Observation

@MainActor
@Observable
final class LineDetailViewModel {
    private(set) var detail: Loadable<LineDetail> = .idle
    var selectedDirectionID: String?
    /// Collapsed "⋯ N gares" runs the user opened; ids are stable across
    /// refreshes, so an expansion survives the automatic reload.
    private(set) var expandedRunIDs: Set<String> = []

    @ObservationIgnored private let repository: any LineStatusRepository
    @ObservationIgnored let lineID: RouteID

    init(repository: any LineStatusRepository, lineID: RouteID) {
        self.repository = repository
        self.lineID = lineID
    }

    /// Keeps the line fresh while its screen is visible; the view owns the
    /// surrounding task, so popping the screen cancels the loop.
    func runAutomaticRefresh(every interval: Duration = .seconds(60)) async {
        await refresh()

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

    func refresh() async {
        detail = .loading(previous: detail.value)
        do {
            detail = .loaded(try await repository.detail(lineID: lineID))
        } catch is CancellationError {
            detail = .failed(.transport, previous: detail.value)
        } catch {
            detail = .failed(error.via, previous: detail.value)
        }
    }

    /// The direction the schema draws: the user's choice, else the first one.
    var selectedDirection: LineDirection? {
        guard let directions = detail.value?.schemaDirections, !directions.isEmpty else {
            return nil
        }
        if let selectedDirectionID,
           let chosen = directions.first(where: { $0.id == selectedDirectionID }) {
            return chosen
        }
        return directions.first
    }

    /// Display rows of the selected direction: sections, stops, folded runs.
    var schemaRows: [LineSchemaLayout.Row] {
        guard let direction = selectedDirection, let detail = detail.value else { return [] }
        return LineSchemaLayout.rows(
            for: direction,
            disruptions: detail.disruptions,
            expandedRunIDs: expandedRunIDs
        )
    }

    func toggleRun(_ runID: String) {
        if !expandedRunIDs.insert(runID).inserted {
            expandedRunIDs.remove(runID)
        }
    }
}
