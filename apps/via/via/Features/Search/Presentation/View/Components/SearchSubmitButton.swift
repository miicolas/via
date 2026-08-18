import SwiftUI

struct SearchSubmitButton: View {
    let action: () -> Void

    var body: some View {
        Button("Rechercher", action: action)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .accessibilityHint("Lance la recherche avec la destination, la date et le départ choisis")
    }
}

#Preview {
    SearchSubmitButton(action: {})
        .padding()
}
