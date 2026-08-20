import Foundation
import os

struct NaturalJourneyMetric: Sendable, Hashable {
    enum Outcome: String, Sendable, Hashable {
        case success
        case clarification
        case unsupported
        case unavailable
        case failure
    }

    let outcome: Outcome
    let firstResultDurationMilliseconds: Int?
    let correctionCount: Int
}

protocol NaturalJourneyMetricsRecording: Sendable {
    func recordInterpretation(durationMilliseconds: Int)
    func recordSearch(_ metric: NaturalJourneyMetric)
}

struct AppLogNaturalJourneyMetrics: NaturalJourneyMetricsRecording {
    func recordInterpretation(durationMilliseconds: Int) {
        AppLog.ai.info(
            "natural_interpretation duration_ms=\(durationMilliseconds, privacy: .public)",
        )
    }

    func recordSearch(_ metric: NaturalJourneyMetric) {
        AppLog.ai.info(
            "natural_search outcome=\(metric.outcome.rawValue, privacy: .public) first_result_ms=\(metric.firstResultDurationMilliseconds ?? -1, privacy: .public) corrections=\(metric.correctionCount, privacy: .public)",
        )
    }
}

struct NoOpNaturalJourneyMetrics: NaturalJourneyMetricsRecording {
    func recordInterpretation(durationMilliseconds _: Int) {}
    func recordSearch(_: NaturalJourneyMetric) {}
}
