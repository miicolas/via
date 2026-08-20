import SwiftUI

struct SearchSubmitButton: View {
    let action: () -> Void

    var body: some View {
        Button("Rechercher", action: action)
            .font(.headline)
            .primaryAction()
            .accessibilityHint("Lance la recherche avec la destination, la date et le départ choisis")
    }
}

#Preview {
    SearchSubmitButton(action: {})
        .padding()
}
