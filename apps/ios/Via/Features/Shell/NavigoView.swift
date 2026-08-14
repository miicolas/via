import SwiftUI

struct NavigoView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(ViaTheme.primary)

                Text("Navigo")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(ViaTheme.ink)

                Text("Retrouvez bientôt vos titres de transport et vos informations de validité dans Via.")
                    .font(.body)
                    .foregroundStyle(ViaTheme.body)

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ViaTheme.ground)
            .navigationTitle("Navigo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
