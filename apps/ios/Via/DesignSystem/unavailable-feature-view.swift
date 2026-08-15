import SwiftUI

struct UnavailableFeatureView: View {
    let title: String
    let description: String
    let systemImage: String
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(ViaTheme.primary)

            Text(title)
                .font(ViaFont.largeTitle)
                .foregroundStyle(ViaTheme.ink)

            Text(description)
                .font(ViaFont.body)
                .foregroundStyle(ViaTheme.body)

            if let actionTitle, let action {
                ViaButton(action: action) {
                    Label(actionTitle, systemImage: "arrow.right")
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ViaTheme.ground)
    }
}
