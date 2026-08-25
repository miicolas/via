import Foundation

/// Apple Intelligence first, Via's server as the fallback. The device keeps
/// every request it can answer — privacy and latency both prefer it — and the
/// server takes over exactly when the local model cannot run at all.
struct HybridNaturalJourneyService: NaturalJourneyRepository {
    let onDevice: any NaturalJourneyRepository
    let remote: any NaturalJourneyRepository
    let availability: @Sendable () -> NaturalLanguageAvailability

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        guard case .submit = request else {
            // Follow-ups carry a draft only the on-device pipeline can hold.
            return try await onDevice.submit(request)
        }

        guard availability() == .available else {
            return try await remote.submit(request)
        }

        do {
            return try await onDevice.submit(request)
        } catch let error as NaturalIntentParsingError {
            switch error {
            case .modelNotReady, .modelFailed:
                // Transient system trouble on an otherwise capable device:
                // the server can still answer this one.
                return try await remote.submit(request)
            case .cancelled, .unsupportedLanguage, .modelBusy, .contextWindowExceeded,
                .contentRefused, .invalidResponse:
                // Signals about the phrase itself. A request the local model
                // refused is not forwarded to an external service.
                throw error
            }
        }
    }
}
