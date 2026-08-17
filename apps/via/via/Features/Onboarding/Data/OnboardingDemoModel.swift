import Foundation
import Observation

enum OnboardingDemoPhase: Equatable {
    case welcome
    case input
    case generating
    case result
}

@MainActor
@Observable
final class OnboardingDemoModel {
    private(set) var phase: OnboardingDemoPhase
    let query: String

    @ObservationIgnored private let generationDelay: Duration
    @ObservationIgnored private var generationTask: Task<Void, Never>?

    init(
        phase: OnboardingDemoPhase = .welcome,
        generationDelay: Duration = .milliseconds(700)
    ) {
        self.phase = phase
        query = OnboardingDemoFixture.query
        self.generationDelay = generationDelay
    }

    var journeyPresentation: JourneyMapPresentation? {
        phase == .result ? OnboardingDemoFixture.mapPresentation : nil
    }

    var journey: Journey {
        OnboardingDemoFixture.journey
    }

    var naturalJourneyResult: NaturalJourneyResult {
        OnboardingDemoFixture.naturalJourneyResult
    }

    func start() {
        guard phase == .welcome else { return }
        phase = .input
    }

    func send() {
        guard phase == .input else { return }

        generationTask?.cancel()
        phase = .generating
        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: generationDelay)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            finishGeneration()
        }
    }

    func reset() {
        generationTask?.cancel()
        generationTask = nil
        phase = .welcome
    }

    private func finishGeneration() {
        guard phase == .generating else { return }
        generationTask = nil
        phase = .result
    }
}
