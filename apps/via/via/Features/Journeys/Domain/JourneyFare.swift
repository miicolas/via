import Foundation

/// Full-price total attached to one route by the official journey planner.
/// Missing is different from free: theoretical fallbacks deliberately carry no fare.
struct JourneyFare: Codable, Sendable, Hashable {
    let amountInCents: Int
    let currency: String

    var displayText: String {
        JourneyFormatting.fare(amountInCents: amountInCents)
    }

    var accessibilityText: String {
        JourneyFormatting.fareAccessibility(amountInCents: amountInCents)
    }
}
