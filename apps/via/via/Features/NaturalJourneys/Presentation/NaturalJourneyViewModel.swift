import Foundation
import Observation

@MainActor
@Observable
final class NaturalJourneyViewModel {
    enum State: Sendable, Equatable {
        case idle
        case loading
        case loaded(NaturalJourneyResult)
        case failed(ViaError)
    }

    var query = ""
    private(set) var state: State = .idle

    @ObservationIgnored private let repository: any NaturalJourneyRepository
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var lastRequest: NaturalJourneyRequest?

    init(repository: any NaturalJourneyRepository) { self.repository = repository }

    func submit(currentLocation: GeoCoordinate?) {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        perform(.submit(query: value, currentLocation: currentLocation))
    }

    func resolve(
        draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
        origin: SearchResult? = nil,
        destination: SearchResult? = nil,
        datetimeRepresents: JourneyDatetimeRepresents? = nil
    ) {
        perform(.resolve(
            draft: draft,
            currentLocation: currentLocation,
            origin: origin,
            destination: destination,
            datetimeRepresents: datetimeRepresents
        ))
    }

    func retry() {
        guard let lastRequest else { return }
        perform(lastRequest)
    }

    func cancel() { task?.cancel() }

    private func perform(_ request: NaturalJourneyRequest) {
        task?.cancel()
        lastRequest = request
        state = .loading
        task = Task {
            do { state = .loaded(try await repository.submit(request)) }
            catch is CancellationError { }
            catch { state = .failed(error.via) }
        }
    }
}
