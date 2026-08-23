import Foundation
import Observation

@MainActor
@Observable
final class JourneyDepartureChoicesModel {
    /// A failure, and the section it belongs to. `nil` means the whole refresh
    /// failed rather than one selection: only one request is ever in flight, so
    /// there can only ever be one.
    struct Failure: Sendable, Equatable {
        var sectionID: String?
        var message: String
    }

    private(set) var groupsBySectionID: [String: JourneyDepartureChoiceGroup] = [:]
    private(set) var isRefreshing = false
    private(set) var selectingSectionID: String?
    private(set) var failure: Failure?

    @ObservationIgnored private let repository: any JourneyDepartureChoicesRepository
    @ObservationIgnored private var requestGeneration = 0

    init(repository: any JourneyDepartureChoicesRepository) {
        self.repository = repository
    }

    /// Keeps the departure choices fresh while the journey is on screen. The
    /// caller owns the surrounding task, so leaving the journey cancels the
    /// loop — the same shape as the other Via view models.
    func runAutomaticRefresh(
        every interval: Duration = .seconds(30),
        journey: @escaping @MainActor () -> Journey,
        destination: JourneyDestination,
        policy: JourneyPlanningPolicy,
        apply: @escaping @MainActor (Journey) async -> Void
    ) async {
        while !Task.isCancelled {
            await refresh(
                journey: journey(),
                destination: destination,
                policy: policy,
                apply: apply
            )
            guard !Task.isCancelled else { return }
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
        }
    }

    func refresh(
        journey: Journey,
        destination: JourneyDestination,
        policy: JourneyPlanningPolicy,
        apply: @escaping @MainActor (Journey) async -> Void
    ) async {
        guard selectingSectionID == nil else { return }
        // Only the first load earns a skeleton; a refresh behind existing
        // choices must not blank them.
        isRefreshing = groupsBySectionID.isEmpty
        await resolve(
            selection: nil,
            journey: journey,
            destination: destination,
            policy: policy,
            apply: apply
        )
    }

    func select(
        _ choice: JourneyDepartureChoice,
        in sectionID: String,
        journey: Journey,
        destination: JourneyDestination,
        policy: JourneyPlanningPolicy,
        apply: @escaping @MainActor (Journey) async -> Void
    ) async {
        // A scroll can settle just as a refresh replaces the choices. Never
        // send an identifier that no longer belongs to the journey snapshot
        // currently on screen: the API correctly rejects that stale pair.
        guard let currentChoice = groupsBySectionID[sectionID]?.choices.first(where: {
            $0.id == choice.id
        }), !currentChoice.isSelected else { return }
        // A swipe that lands while an earlier one is still in flight supersedes
        // it rather than being dropped: the generation guard in `resolve` makes
        // the abandoned answer harmless, and the traveller's last gesture is
        // always the one that wins.
        selectingSectionID = sectionID
        await resolve(
            selection: JourneyDepartureSelection(sectionID: sectionID, departureID: choice.id),
            journey: journey,
            destination: destination,
            policy: policy,
            apply: apply
        )
    }

    func reset() {
        _ = nextGeneration()
        groupsBySectionID = [:]
        selectingSectionID = nil
        failure = nil
        isRefreshing = false
    }

    /// The message a section should show: its own, or the one from a refresh
    /// that failed for the whole journey.
    func errorMessage(for sectionID: String) -> String? {
        guard let failure, failure.sectionID == nil || failure.sectionID == sectionID
        else { return nil }
        return failure.message
    }

    /// The one request path. A selection and a refresh differ only in what they
    /// ask for and which busy flag they raised — keeping the generation guard
    /// and the cancellation handling in one place is the point.
    ///
    /// Keeps the last good choices visible on failure. A monotonically
    /// increasing generation makes late network responses harmless.
    private func resolve(
        selection: JourneyDepartureSelection?,
        journey: Journey,
        destination: JourneyDestination,
        policy: JourneyPlanningPolicy,
        apply: @escaping @MainActor (Journey) async -> Void
    ) async {
        let generation = nextGeneration()
        failure = nil
        do {
            let snapshot = try await repository.resolve(.init(
                journey: journey,
                destination: destination,
                policy: policy,
                selection: selection
            ))
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }
            // A selection always revised the journey; a refresh only did if the
            // server actually spliced something.
            if selection != nil || snapshot.journey != journey {
                await apply(snapshot.journey)
            }
            groupsBySectionID = Dictionary(
                uniqueKeysWithValues: snapshot.groups.map { ($0.sectionID, $0) }
            )
            clearBusyFlags()
        } catch is CancellationError {
            guard generation == requestGeneration else { return }
            clearBusyFlags()
        } catch {
            guard generation == requestGeneration else { return }
            clearBusyFlags()
            failure = Failure(
                sectionID: selection?.sectionID,
                message: Self.message(for: error)
            )
        }
    }

    private func clearBusyFlags() {
        isRefreshing = false
        selectingSectionID = nil
    }

    private func nextGeneration() -> Int {
        requestGeneration += 1
        return requestGeneration
    }

    private static func message(for error: Error) -> String {
        switch error.via {
        case .transport:
            "Horaires directs indisponibles hors connexion."
        case .unavailable:
            "Aucun autre passage n’est disponible."
        default:
            "Impossible d’actualiser ce passage. Réessayez."
        }
    }
}
