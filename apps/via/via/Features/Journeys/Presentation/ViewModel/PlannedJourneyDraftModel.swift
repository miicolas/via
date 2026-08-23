import Foundation
import Observation

@MainActor
@Observable
final class PlannedJourneyDraftModel {
    private(set) var draft: PlannedJourneyDraft?
    private(set) var isUpdating = false
    private(set) var lastError: String?

    @ObservationIgnored private let store: any PlannedJourneyDraftStoring
    @ObservationIgnored private let now: @Sendable () -> Date

    init(
        store: any PlannedJourneyDraftStoring = InMemoryPlannedJourneyDraftStore(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.store = store
        self.now = now
    }

    func restore() async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            draft = try await store.load()
            lastError = nil
        } catch {
            draft = nil
            await store.clear()
            lastError = "Un trajet prévu illisible a été supprimé de cet appareil."
        }
    }

    @discardableResult
    func plan(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy
    ) async -> Bool {
        let candidate = PlannedJourneyDraft(
            journey: journey,
            destination: destination,
            source: source,
            planningPolicy: planningPolicy,
            plannedAt: now()
        )

        isUpdating = true
        defer { isUpdating = false }
        do {
            try await store.save(candidate)
            draft = candidate
            lastError = nil
            return true
        } catch {
            lastError = "Le trajet n’a pas pu être prévu sur cet appareil."
            return false
        }
    }

    func applyJourneyRevision(_ journey: Journey) async {
        guard let current = draft, current.journey.id == journey.id else { return }
        let revised = PlannedJourneyDraft(
            journey: journey,
            destination: current.destination,
            source: current.source,
            planningPolicy: current.planningPolicy,
            plannedAt: current.plannedAt
        )

        isUpdating = true
        defer { isUpdating = false }
        do {
            try await store.save(revised)
            draft = revised
            lastError = nil
        } catch {
            lastError = "Le trajet prévu n’a pas pu être mis à jour."
        }
    }

    /// Starts the current draft and removes it only after the active model has
    /// accepted that exact journey. This keeps a failed launch retryable.
    @discardableResult
    func launch(
        using activeJourneyModel: ActiveJourneyModel,
        allowsBackgroundTracking: Bool
    ) async -> Bool {
        guard let candidate = draft else { return false }
        await activeJourneyModel.go(
            journey: candidate.journey,
            destination: candidate.destination,
            source: candidate.source,
            planningPolicy: candidate.planningPolicy,
            allowsBackgroundTracking: allowsBackgroundTracking
        )
        guard activeJourneyModel.session?.journey.id == candidate.journey.id else {
            return false
        }
        await consume(candidate)
        return true
    }

    /// Consumes only the exact draft that started. A newer revision planned
    /// while launch was in flight must never be removed by the older task.
    func consume(_ candidate: PlannedJourneyDraft) async {
        guard draft == candidate else { return }
        draft = nil
        lastError = nil
        await store.clear()
    }
}
