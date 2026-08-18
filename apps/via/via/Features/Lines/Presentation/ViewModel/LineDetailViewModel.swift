import Foundation
import Observation

@MainActor
@Observable
final class LineDetailViewModel {
    private(set) var detail: Loadable<LineDetail> = .idle
    var selectedBranchID: String?

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

    /// The branch the schema draws: the user's choice, else the canonical
    /// pattern of the first direction, else the first branch.
    var selectedBranch: LineBranch? {
        guard let branches = detail.value?.branches, !branches.isEmpty else { return nil }
        if let selectedBranchID, let chosen = branches.first(where: { $0.id == selectedBranchID }) {
            return chosen
        }
        return branches.first(where: \.isCanonical) ?? branches.first
    }

    /// Inter-station segments of the selected branch inside an active cut.
    var cutSegments: Set<Int> {
        guard let branch = selectedBranch, let detail = detail.value else { return [] }
        return branch.cutSegmentIndexes(for: detail.disruptions)
    }

    /// Stops the active disruptions call out on the selected branch.
    var affectedStopIDs: Set<String> {
        guard let branch = selectedBranch, let detail = detail.value else { return [] }
        let branchStopIDs = Set(branch.stops.map(\.id))
        var affected: Set<String> = []
        for disruption in detail.activeDisruptions {
            for section in disruption.impactedSections {
                for stopID in [section.fromStopID, section.toStopID]
                where branchStopIDs.contains(stopID) {
                    affected.insert(stopID)
                }
            }
        }
        return affected
    }
}
