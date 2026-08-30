import Foundation

/// One counter for how many times the traveller corrected a natural-language
/// search. The dialogue increments it while the conversation runs; the search
/// surface keeps incrementing it when the interpreted criteria are edited
/// after the answer landed. Sharing the tally keeps the metrics identical to
/// when a single view model owned the number.
@MainActor
final class NaturalJourneyCorrectionTally {
    private(set) var count = 0

    func increment() {
        count += 1
    }

    func reset() {
        count = 0
    }
}
