import SwiftUI

/// The running journey reduced to its strip, built straight from the model.
///
/// Two sheets show this strip at their peek — the tab sheet and the journey
/// sheet — and both need the same three values to be present before it means
/// anything. Unwrapping them here is what keeps the two from disagreeing about
/// when the strip appears.
struct ActiveJourneyCompactStrip: View {
    let model: ActiveJourneyModel
    let action: () -> Void

    var body: some View {
        if let journey = model.journey,
           let headline = model.guidanceHeadline {
            ActiveJourneyCompactView(
                journey: journey,
                headline: headline,
                currentSectionIndex: model.currentSectionIndex,
                action: action
            )
        }
    }
}
