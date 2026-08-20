import SwiftUI

struct StationRefreshStatusView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 4)

            RetryButton(action: onRetry)
                .iconAction(size: .small)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StationRefreshStatusView(
        message: "Le service est momentanément indisponible.",
        onRetry: {}
    )
    .padding()
}
