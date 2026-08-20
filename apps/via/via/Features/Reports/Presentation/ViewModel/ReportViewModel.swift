import Foundation
import Observation

enum ReportSheetDestination: String, Identifiable, Sendable, Equatable {
    case stationPicker
    case crowdingPicker

    var id: String { rawValue }
}

enum ReportSubmissionState: Sendable, Equatable {
    case idle
    case submitting(ReportSubmission)
    case failed(ReportSubmission, ViaError)
    case confirmed(ReportSubmission)

    var isSubmitting: Bool {
        if case .submitting = self { return true }
        return false
    }

    var submittingCategory: ReportCategory? {
        guard case .submitting(let submission) = self else { return nil }
        return submission.category
    }
}

enum ReportStationSearchState: Sendable, Equatable {
    case idle
    case loading
    case loaded([StationSearchResult])
    case empty
    case failed(ViaError)
}

@MainActor
@Observable
final class ReportViewModel {
    let contextResolver: ReportContextResolver

    private(set) var submissionState: ReportSubmissionState = .idle
    private(set) var stationSearchState: ReportStationSearchState = .idle
    private(set) var activeJourney: ActiveJourneyContext?

    var presentedSheet: ReportSheetDestination?
    var stationQuery: String = "" {
        didSet {
            guard stationQuery != oldValue else { return }
            scheduleStationSearch()
        }
    }

    @ObservationIgnored private let repository: any ReportRepository
    @ObservationIgnored private let searchRepository: any SearchRepository
    @ObservationIgnored private let activeJourneyProvider: any ActiveJourneyProvider
    @ObservationIgnored private let makeID: @Sendable () -> UUID
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var submissionTask: Task<Void, Never>?
    @ObservationIgnored private var stationSearchTask: Task<Void, Never>?
    @ObservationIgnored private var activeJourneyTask: Task<Void, Never>?
    @ObservationIgnored private var lastStationQuery = ""

    init(
        contextResolver: ReportContextResolver,
        repository: any ReportRepository,
        searchRepository: any SearchRepository,
        activeJourneyProvider: any ActiveJourneyProvider = NoActiveJourneyProvider(),
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.contextResolver = contextResolver
        self.repository = repository
        self.searchRepository = searchRepository
        self.activeJourneyProvider = activeJourneyProvider
        self.makeID = makeID
        self.now = now
    }

    var canSubmit: Bool {
        guard contextResolver.state.selection != nil else { return false }
        if case .idle = submissionState { return true }
        return false
    }

    var isPresentingAnotherSheet: Bool {
        presentedSheet != nil
    }

    func loadIfNeeded() {
        contextResolver.loadIfNeeded()
        activeJourneyTask?.cancel()
        let activeJourneyProvider = self.activeJourneyProvider
        activeJourneyTask = Task { [weak self] in
            let journey = await activeJourneyProvider.activeJourney()
            guard !Task.isCancelled else { return }
            self?.activeJourney = journey
        }
    }

    func presentStationPicker() {
        presentedSheet = .stationPicker
    }

    func selectCategory(_ category: ReportCategory) {
        guard canSubmit else { return }

        if category == .crowding {
            presentedSheet = .crowdingPicker
        } else {
            submit(category: category, value: .occurrence)
        }
    }

    func selectCrowdingLevel(_ level: CrowdingLevel) {
        guard presentedSheet == .crowdingPicker else { return }
        presentedSheet = nil
        submit(category: .crowding, value: .crowding(level))
    }

    func cancelPresentedSheet() {
        presentedSheet = nil
    }

    func selectStation(_ station: StationSearchResult) {
        contextResolver.selectManualStation(station)
        stationSearchTask?.cancel()
        stationQuery = ""
        stationSearchState = .idle
        presentedSheet = nil
    }

    func retryContextResolution() {
        contextResolver.retry()
    }

    func retrySubmission() {
        guard case .failed(let submission, _) = submissionState else { return }
        performSubmission(submission)
    }

    func finishConfirmation() {
        guard case .confirmed = submissionState else { return }
        submissionState = .idle
    }

    func retryStationSearch() {
        let query = lastStationQuery.isEmpty
            ? stationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            : lastStationQuery
        guard query.count >= 2 else { return }

        stationSearchTask?.cancel()
        stationSearchTask = Task { [weak self] in
            await self?.performStationSearch(query)
        }
    }

    func clearStationQuery() {
        stationQuery = ""
    }

    func searchStationsImmediately() {
        let query = stationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return }

        stationSearchTask?.cancel()
        stationSearchTask = Task { [weak self] in
            await self?.performStationSearch(query)
        }
    }

    private func submit(category: ReportCategory, value: ReportValue) {
        guard canSubmit, let selection = contextResolver.state.selection else { return }

        let submission = ReportSubmission(
            id: makeID(),
            category: category,
            value: value,
            context: selection.context(activeJourney: activeJourney),
            submittedAt: now()
        )
        performSubmission(submission)
    }

    private func performSubmission(_ submission: ReportSubmission) {
        guard !submissionState.isSubmitting else { return }

        submissionTask?.cancel()
        submissionState = .submitting(submission)
        let repository = self.repository

        submissionTask = Task { [weak self] in
            do {
                try await repository.submit(submission)
                try Task.checkCancellation()
                self?.submissionState = .confirmed(submission)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                self?.submissionState = .failed(submission, error.via)
            }
        }
    }

    private func scheduleStationSearch() {
        stationSearchTask?.cancel()
        let query = stationQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard query.count >= 2 else {
            lastStationQuery = ""
            stationSearchState = .idle
            return
        }

        stationSearchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await self?.performStationSearch(query)
        }
    }

    private func performStationSearch(_ query: String) async {
        stationSearchState = .loading
        lastStationQuery = query

        do {
            let response = try await searchRepository.search(
                query: query,
                near: contextResolver.state.selection?.coordinate
            )
            try Task.checkCancellation()

            let stations = response.results.compactMap { result -> StationSearchResult? in
                guard case .station(let station) = result else { return nil }
                return station
            }
            stationSearchState = stations.isEmpty ? .empty : .loaded(stations)
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            stationSearchState = .failed(error.via)
        }
    }
}
