import SwiftUI

struct SearchBarView: View {
    @Binding var query: String
    let onFocusChanged: (Bool) -> Void
    @FocusState private var isFocused

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ViaTheme.muted)

            TextField("Rechercher une station ou une adresse", text: $query)
                .font(.body)
                .focused($isFocused)
                .accessibilityIdentifier("via.searchField")
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onChange(of: isFocused) { _, focused in
                    onFocusChanged(focused)
                }

            if !query.isEmpty {
                ViaButton(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ViaTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }
}
