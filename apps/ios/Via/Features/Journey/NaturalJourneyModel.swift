import Foundation
import Observation

@MainActor
@Observable
final class NaturalJourneyModel {
    let transitAPI: any TransitAPI

    var state: NaturalJourneyState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((NaturalJourneyState) -> Void)?

    private var request: NaturalJourneyRequest?
    private var task: Task<Void, Never>?

    init(transitAPI: any TransitAPI) {
        self.transitAPI = transitAPI
    }

    func submit(_ query: String, currentLocation: GeoCoordinate?) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        run(
            .submit(query: trimmed, currentLocation: currentLocation)
        )
    }

    @discardableResult
    func resolve(
        _ choice: NaturalJourneyChoice,
        currentLocation: GeoCoordinate?
    ) -> Bool {
        guard case .needsClarification(let clarification) = state else { return false }

        let request: NaturalJourneyRequest?
        switch choice {
        case .place(let target, let result):
            switch target {
            case .origin:
                request = .resolve(
                    draft: clarification.draft,
                    currentLocation: currentLocation,
                    origin: result,
                    destination: nil,
                    datetimeRepresents: nil
                )
            case .destination:
                request = .resolve(
                    draft: clarification.draft,
                    currentLocation: currentLocation,
                    origin: nil,
                    destination: result,
                    datetimeRepresents: nil
                )
            case .time:
                request = nil
            }
        case .time(let value):
            request = .resolve(
                draft: clarification.draft,
                currentLocation: currentLocation,
                origin: nil,
                destination: nil,
                datetimeRepresents: value
            )
        }

        guard let request else { return false }
        run(request)
        return true
    }

    @discardableResult
    func retry() -> Bool {
        guard let request else { return false }
        run(request)
        return true
    }

    func cancel() {
        task?.cancel()
        task = nil
        request = nil
        state = .idle
    }

    private func run(_ request: NaturalJourneyRequest) {
        task?.cancel()
        self.request = request
        state = .interpreting
        task = Task { [weak self] in
            guard let self else { return }

            do {
                let response = try await transitAPI.submitNaturalJourney(request)
                guard !Task.isCancelled, self.request == request else { return }
                state = response.state
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, self.request == request else { return }
                state = .failed(
                    .unavailable(
                        reason: .ai,
                        message: "La recherche en langage naturel est indisponible. La recherche classique reste accessible."
                    )
                )
            }
        }
    }
}

private extension NaturalJourneyResponse {
    var state: NaturalJourneyState {
        switch self {
        case .ready(let response): .ready(response)
        case .needsClarification(let clarification): .needsClarification(clarification)
        case .failure(let failure): .failed(failure)
        }
    }
}
