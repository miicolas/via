import Foundation
import Observation

@MainActor
@Observable
final class LineDetailViewModel {
    private(set) var detail: Loadable<LineDetail> = .idle
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
        return LinePlan.diagramStrips(for: direction, disruptions: detail.disruptions)
    }

}
