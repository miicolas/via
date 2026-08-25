import Foundation
import os

enum NaturalJourneyProcessingPath: String, Sendable, Hashable {
    case deterministic
    case localModel
    case serverModel
    case unknown
}

enum NaturalJourneyMetricStage: String, Sendable, Hashable {
    case interpretation
    case placeResolution
    case planning
}

enum NaturalJourneyPerformanceSLO {
    static let localInterpretationP95Milliseconds = 2_500
    static let serverInterpretationP95Milliseconds = 5_000
    static let firstResultP95Milliseconds = 8_000
}

struct NaturalJourneyMetric: Sendable, Hashable {
    enum Outcome: String, Sendable, Hashable {
        case success
        case clarification
        case unsupported
        case unavailable
        case failure
        case incorrectExecution
    }

    let outcome: Outcome
    let firstResultDurationMilliseconds: Int?
    let correctionCount: Int
    let processingPath: NaturalJourneyProcessingPath
    let osMajorVersion: Int

    init(
        outcome: Outcome,
        firstResultDurationMilliseconds: Int?,
        correctionCount: Int,
        processingPath: NaturalJourneyProcessingPath = .unknown,
        osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
    ) {
        self.outcome = outcome
        self.firstResultDurationMilliseconds = firstResultDurationMilliseconds
        self.correctionCount = correctionCount
        self.processingPath = processingPath
        self.osMajorVersion = osMajorVersion
    }
}

protocol NaturalJourneyMetricsRecording: Sendable {
    func recordInterpretation(durationMilliseconds: Int)
    func recordStage(
        _ stage: NaturalJourneyMetricStage,
        path: NaturalJourneyProcessingPath,
        durationMilliseconds: Int,
    )
    func recordSearch(_ metric: NaturalJourneyMetric)
}

extension NaturalJourneyMetricsRecording {
    func recordStage(
        _ stage: NaturalJourneyMetricStage,
        path _: NaturalJourneyProcessingPath,
        durationMilliseconds: Int,
    ) {
        if stage == .interpretation {
            recordInterpretation(durationMilliseconds: durationMilliseconds)
        }
    }
}

struct AppLogNaturalJourneyMetrics: NaturalJourneyMetricsRecording {
    func recordInterpretation(durationMilliseconds: Int) {
        AppLog.ai.info(
            "natural_interpretation duration_ms=\(durationMilliseconds, privacy: .public)",
        )
    }

    func recordStage(
        _ stage: NaturalJourneyMetricStage,
        path: NaturalJourneyProcessingPath,
        durationMilliseconds: Int,
    ) {
        let osMajor = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        AppLog.ai.info(
            "natural_pipeline stage=\(stage.rawValue, privacy: .public) path=\(path.rawValue, privacy: .public) ios_major=\(osMajor, privacy: .public) duration_ms=\(durationMilliseconds, privacy: .public)",
        )
    }

    func recordSearch(_ metric: NaturalJourneyMetric) {
        AppLog.ai.info(
            "natural_search outcome=\(metric.outcome.rawValue, privacy: .public) path=\(metric.processingPath.rawValue, privacy: .public) ios_major=\(metric.osMajorVersion, privacy: .public) first_result_ms=\(metric.firstResultDurationMilliseconds ?? -1, privacy: .public) corrections=\(metric.correctionCount, privacy: .public)",
        )
    }
}

struct NoOpNaturalJourneyMetrics: NaturalJourneyMetricsRecording {
    func recordInterpretation(durationMilliseconds _: Int) {}
    func recordStage(
        _: NaturalJourneyMetricStage,
        path _: NaturalJourneyProcessingPath,
        durationMilliseconds _: Int,
    ) {}
    func recordSearch(_: NaturalJourneyMetric) {}
}
