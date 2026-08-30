import Foundation

enum MeetupFeatureFlags {
    static let rendezVousKey = "feature.rendez-vous.enabled"
    static let precisePresenceKey = "meetup.precise-presence-enabled"

    /// Release tooling can set this managed preference to disable every entry
    /// point without removing the shipped implementation. Absence means on.
    static var rendezVousEnabled: Bool { isEnabled(rendezVousKey) }

    static var precisePresenceEnabled: Bool { isEnabled(precisePresenceKey) }

    /// Absence means on: a managed preference that was never pushed must not
    /// read as a kill switch someone deliberately threw.
    private static func isEnabled(_ key: String) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
}
