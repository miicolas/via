import Foundation
import Observation

@MainActor
@Observable
final class LineDetailViewModel {
    private(set) var detail: Loadable<LineDetail> = .idle
    /// Branches the rider opened; ids are stable across refreshes, so an open
    /// branch survives the automatic reload.
    private(set) var openedBranchIDs: Set<String> = []

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

    /// The trunk and its branches, in reading order.
    var strips: [LinePlan.Strip] {
        guard let detail = detail.value, let direction = detail.planDirection else { return [] }
        return LinePlan.strips(for: direction, disruptions: detail.disruptions)
    }

    /// A branch opens on a tap, and a disrupted one opens by itself: the
    /// screen's job is to show where the problem is, not to hide it one tap
    /// deep.
    func isOpen(_ strip: LinePlan.Strip) -> Bool {
        strip.role == .trunk || strip.condition != nil || openedBranchIDs.contains(strip.id)
    }

    func toggle(_ strip: LinePlan.Strip) {
        if !openedBranchIDs.insert(strip.id).inserted {
            openedBranchIDs.remove(strip.id)
        }
    }
}
