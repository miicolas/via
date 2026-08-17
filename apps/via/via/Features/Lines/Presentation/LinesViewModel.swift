import Foundation
import Observation

@MainActor
@Observable
final class LinesViewModel {
    private(set) var statuses: Loadable<[LineStatus]> = .idle
    var selectedNetwork: String?
    var selectedMode: TransitMode?
    var selectedDirection: String?
    var disruptionsOnly = false

    @ObservationIgnored private let repository: any LineStatusRepository

    init(repository: any LineStatusRepository) {
        self.repository = repository
    }

    var visibleStatuses: [LineStatus] {
        (statuses.value ?? [])
            .filter { status in
                guard let selectedNetwork else { return true }
                return status.network == selectedNetwork
            }
            .filter { status in
                guard let selectedMode else { return true }
                return status.mode == selectedMode
            }
            .filter { status in
                guard let selectedDirection else { return true }
                return status.direction == selectedDirection
            }
            .filter { status in
                !disruptionsOnly || status.condition != .normal
            }
            .sorted {
                if $0.condition.severity != $1.condition.severity {
                    return $0.condition.severity < $1.condition.severity
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    var networks: [String] {
        Array(Set(statuses.value?.map(\.network) ?? [])).sorted()
    }

    var directions: [String] {
        Array(Set(statuses.value?.map(\.direction) ?? [])).sorted()
    }

    var isLoading: Bool {
        if case .loading = statuses { return true }
        return false
    }

    func load() async {
        guard !isLoading else { return }
        let previous = statuses.value
        statuses = .loading(previous: previous)

        do {
            statuses = .loaded(try await repository.loadStatuses())
        } catch is CancellationError {
            statuses = previous.map(Loadable.loaded) ?? .idle
        } catch {
            statuses = .failed(error.via, previous: previous)
        }
    }

    func resetFilters() {
        selectedNetwork = nil
        selectedMode = nil
        selectedDirection = nil
        disruptionsOnly = false
    }
}
