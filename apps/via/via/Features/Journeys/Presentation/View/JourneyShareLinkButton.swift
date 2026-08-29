import SwiftUI

/// Shares one URL item so every destination keeps the opaque token intact.
/// A separate ShareLink message used to be concatenated to the URL by some
/// activities, turning an otherwise valid public link into a 404.
struct JourneyShareLinkButton: View {
    let url: URL

    var body: some View {
        ShareLink(item: url) {
            Label("Partager le trajet", systemImage: "square.and.arrow.up")
        }
    }
}
