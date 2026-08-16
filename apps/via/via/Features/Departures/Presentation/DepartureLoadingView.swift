import SwiftUI

struct DepartureLoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()

            Text("Chargement des prochains passages…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.primary.opacity(0.045))
        }
    }
}
