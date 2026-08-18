import Foundation
import os

struct HybridNaturalJourneyRepository: NaturalJourneyRepository {
    private let parser: any NaturalIntentParsing
    private let onDevice: any NaturalJourneyRepository
    private let remote: any NaturalJourneyRepository

    init(
        parser: any NaturalIntentParsing,
        onDevice: any NaturalJourneyRepository,
        remote: any NaturalJourneyRepository
    ) {
        self.parser = parser
        self.onDevice = onDevice
        self.remote = remote
    }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        let startedAt = Date()
        switch parser.availability {
        case .available:
            do {
                let result = try await onDevice.submit(request)
                Self.log(result, path: "on_device", startedAt: startedAt)
                return result
            } catch NaturalIntentParsingError.cancelled {
                throw CancellationError()
            } catch let parsingError as NaturalIntentParsingError {
                AppLog.ai.notice(
                    "natural journey fallback=server reason=\(Self.label(parsingError), privacy: .public)"
                )
                return try await submitRemote(
                    request,
                    unavailableReason: nil,
                    startedAt: startedAt
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as ViaError {
                AppLog.ai.error(
                    "natural journey path=on_device transport_error=\(String(describing: error), privacy: .public)"
                )
                throw error
            }
        case .unavailable(let reason):
            AppLog.ai.notice(
                "natural journey path=server local_unavailable=\(Self.label(reason), privacy: .public)"
            )
            return try await submitRemote(
                request,
                unavailableReason: reason,
                startedAt: startedAt
            )
        }
    }

    private func submitRemote(
        _ request: NaturalJourneyRequest,
        unavailableReason: NaturalLanguageUnavailableReason?,
        startedAt: Date
    ) async throws -> NaturalJourneyResult {
        do {
            let result = try await remote.submit(request)
            Self.log(result, path: "server", startedAt: startedAt)
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard let unavailableReason,
                  let explanation = Self.doubleFailure(for: unavailableReason) else {
                AppLog.ai.error(
                    "natural journey path=server failed_after_fallback=true"
                )
                throw error
            }
            AppLog.ai.error(
                "natural journey paths_failed=true guidance=\(Self.guidanceLabel(explanation.guidance), privacy: .public)"
            )
            return .unavailable(
                message: explanation.message,
                guidance: explanation.guidance
            )
        }
    }

    private static func doubleFailure(
        for reason: NaturalLanguageUnavailableReason
    ) -> (message: String, guidance: NaturalJourneyUnavailableGuidance)? {
        switch reason {
        case .appleIntelligenceDisabled:
            (
                "Active Apple Intelligence pour utiliser la recherche en langage naturel lorsque le serveur est indisponible.",
                .enableAppleIntelligence
            )
        case .modelNotReady:
            (
                "Le modèle Apple Intelligence est en cours de téléchargement. Réessaie lorsqu’il sera prêt.",
                .modelDownloading
            )
        case .deviceNotEligible, .unsupportedLanguage:
            nil
        }
    }

    private static func log(
        _ result: NaturalJourneyResult,
        path: String,
        startedAt: Date
    ) {
        let latencyMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        AppLog.ai.info(
            "natural journey path=\(path, privacy: .public) latency_ms=\(latencyMs) status=\(status(result), privacy: .public) answer_source=\(answerSource(result), privacy: .public)"
        )
    }

    private static func status(_ result: NaturalJourneyResult) -> String {
        switch result {
        case .ready: "ready"
        case .needsClarification: "needs_clarification"
        case .unsupported: "unsupported"
        case .unavailable: "unavailable"
        case .rateLimited: "rate_limited"
        }
    }

    private static func answerSource(_ result: NaturalJourneyResult) -> String {
        guard case .ready(_, let source, _, _, _) = result else { return "none" }
        return switch source {
        case .onDevice: "on_device"
        case .server: "server"
        case .deterministic: "deterministic"
        }
    }

    private static func label(_ reason: NaturalLanguageUnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible: "device_not_eligible"
        case .appleIntelligenceDisabled: "apple_intelligence_disabled"
        case .modelNotReady: "model_not_ready"
        case .unsupportedLanguage: "unsupported_language"
        }
    }

    private static func label(_ error: NaturalIntentParsingError) -> String {
        switch error {
        case .cancelled: "cancelled"
        case .modelNotReady: "model_not_ready"
        case .unsupportedLanguage: "unsupported_language"
        case .modelBusy: "model_busy"
        case .contextWindowExceeded: "context_window_exceeded"
        case .contentRefused: "content_refused"
        case .invalidResponse: "invalid_response"
        case .modelFailed: "model_failed"
        }
    }

    private static func guidanceLabel(_ guidance: NaturalJourneyUnavailableGuidance) -> String {
        switch guidance {
        case .enableAppleIntelligence: "enable_apple_intelligence"
        case .modelDownloading: "model_downloading"
        }
    }
}
