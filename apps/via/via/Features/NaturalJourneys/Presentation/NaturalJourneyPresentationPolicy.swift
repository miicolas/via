enum NaturalJourneyPresentationPolicy {
    static let entryAccessibilityLabel = "Rechercher avec Apple Intelligence"
    static let entryAccessibilityHint = "Décris ton trajet dans une phrase"

    static func expandsForInput(_ state: NaturalSearchState) -> Bool {
        state == .input
    }
}
