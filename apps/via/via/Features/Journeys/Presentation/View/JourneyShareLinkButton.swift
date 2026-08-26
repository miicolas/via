import SwiftUI

/// The one wording a recipient reads, wherever the sender shares from.
///
/// The sheet that has just created a link and the sheet that opens one both
/// present it; written twice, the subject and the message the recipient sees
/// could be reworded on one screen and not the other. The presentation — a
/// toolbar icon or a full-width action — stays with the call site.
struct JourneyShareLinkButton: View {
    let url: URL

    var body: some View {
        ShareLink(
            item: url,
            subject: Text("Trajet Metyro"),
            message: Text("Voici un trajet partagé dans Metyro.")
        ) {
            Label("Partager le trajet", systemImage: "square.and.arrow.up")
        }
    }
}
