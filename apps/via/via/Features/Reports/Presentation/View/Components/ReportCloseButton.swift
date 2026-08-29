import SwiftUI

struct ReportCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassSquareBadge(tint: .gray, size: 36, isInteractive: true) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .accessibilityLabel("Fermer")
    }
}
