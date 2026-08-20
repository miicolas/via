enum NaturalLanguageUnavailableReason: Sendable, Hashable {
    case deviceNotEligible
    case appleIntelligenceDisabled
    case modelNotReady
    case unsupportedLanguage
}

enum NaturalLanguageAvailability: Sendable, Hashable {
    case available
    case unavailable(NaturalLanguageUnavailableReason)

    var access: NaturalLanguageAccess {
        switch self {
        case .available:
            .active
        case .unavailable(.appleIntelligenceDisabled):
            .explanation(.enableAppleIntelligence)
        case .unavailable(.modelNotReady):
            .explanation(.modelDownloading)
        case .unavailable(.deviceNotEligible), .unavailable(.unsupportedLanguage):
            .hidden
        }
    }
}

enum NaturalLanguageAccess: Sendable, Hashable {
    case active
    case explanation(NaturalJourneyUnavailableGuidance)
    case hidden
}
