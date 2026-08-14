import SwiftUI

struct LocationPermissionCardView: View {
    let title: String
    let message: String
    let primaryTitle: LocalizedStringKey
    let primarySystemImage: String
    let primaryAction: () -> Void
    let secondaryTitle: LocalizedStringKey
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "location")
                .font(.headline)
                .foregroundStyle(ViaTheme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(ViaTheme.body)
            HStack(spacing: 10) {
                ViaButton(primaryTitle, systemImage: primarySystemImage, action: primaryAction)
                ViaButton(action: secondaryAction) {
                    Text(secondaryTitle)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ViaTheme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
