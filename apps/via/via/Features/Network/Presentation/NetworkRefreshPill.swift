import SwiftUI

struct NetworkRefreshPill: View {
    var body: some View {
        ViaLoadingStatus(label: "Actualisation du réseau…")
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
    }
}

#Preview {
    NetworkRefreshPill()
}
