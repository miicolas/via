import Foundation

enum NaturalJourneyProcessingPreference {
    static let serverFallbackKey = "naturalJourney.serverFallback.enabled"

    /// Reliability-first default, disclosed in onboarding and reversible in
    /// Settings. `object` distinguishes an unset preference from an explicit
    /// Local-only choice.
    static func allowsServerFallback(
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard defaults.object(forKey: serverFallbackKey) != nil else { return true }
        return defaults.bool(forKey: serverFallbackKey)
    }
}
