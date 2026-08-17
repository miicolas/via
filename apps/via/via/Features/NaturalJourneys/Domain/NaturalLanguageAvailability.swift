enum NaturalLanguageUnavailableReason: Sendable, Hashable {
    case deviceNotEligible
    case appleIntelligenceDisabled
    case modelNotReady
    case unsupportedLanguage
}

enum NaturalLanguageAvailability: Sendable, Hashable {
    case available
    case unavailable(NaturalLanguageUnavailableReason)
}
