import Foundation
import Observation

enum ReportViewState: Sendable, Equatable {
    case ready
    case submitting(ReportCategory)
    case completed(ReportSubmission)
    case failed(ViaError)
}

@MainActor
@Observable
final class ReportViewModel {
    private(set) var state: ReportViewState = .ready

    @ObservationIgnored private let locationModel: LocationModel
    @ObservationIgnored private let repository: any ReportRepository
    @ObservationIgnored private let now: @Sendable () -> Date

    init(
        locationModel: LocationModel,
        repository: any ReportRepository,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.locationModel = locationModel
        self.repository = repository
        self.now = now
    }

    func requestLocationIfNeeded() {
        guard locationModel.coordinate == nil else { return }
        locationModel.requestLocation()
    }

    func submit(_ category: ReportCategory) {
        guard case .ready = state else { return }

        let report = ReportSubmission(
            category: category,
            context: ReportContext(
                // Keep only a rounded coordinate until the server contract
                // decides whether a more precise location is appropriate.
                coordinate: locationModel.coordinate?.roundedForSearch
            ),
            observedAt: now()
        )

        state = .submitting(category)
        let repository = self.repository

        Task { [weak self] in
            do {
                try await repository.submit(report)
                guard !Task.isCancelled else { return }
                self?.state = .completed(report)
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .failed(error.via)
            }
        }
    }

    func reset() {
        state = .ready
    }
}
