import SwiftUI

/// Shown when the disruptions feed cannot be read: the catalogue stays, but a
/// green-less banner keeps "no data" from reading as "all clear".
struct LinesUnavailableBanner: View {
    var body: some View {
        Label(
            "L’état du trafic est indisponible pour le moment.",
            systemImage: "wifi.exclamationmark"
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    List {
        LinesUnavailableBanner()
    }
}
