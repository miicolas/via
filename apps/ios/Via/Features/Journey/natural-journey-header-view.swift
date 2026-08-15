import SwiftUI

struct NaturalJourneyHeaderView: View {
    let title: String
    let subtitle: String
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ViaTheme.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(ViaTheme.muted)
            }
            Spacer()
            ViaButton(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer le trajet naturel")
        }
    }
}
