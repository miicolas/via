import SwiftUI

struct StationsEmptyStateView: View {
    let title: String
    let message: String?
    let onOpenSearch: () -> Void
    let onRetry: (() -> Void)?

    init(
        title: String = "Trouvez une station",
        message: String? = nil,
        onOpenSearch: @escaping () -> Void,
        onRetry: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.onOpenSearch = onOpenSearch
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)

            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onOpenSearch) {
                Text("Touchez \(Image(systemName: "magnifyingglass.circle.fill")) Recherche pour trouver une station près de vous")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityLabel("Ouvrir Recherche pour trouver une station")

            if let onRetry {
                RetryButton(action: onRetry)
                    .secondaryAction()
                    .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

#Preview {
    StationsEmptyStateView(onOpenSearch: {})
        .frame(height: 500)
}

#Preview("Location unavailable") {
    StationsEmptyStateView(
        title: "Localisation indisponible",
        message: "La position est en cours de recherche.",
        onOpenSearch: {},
        onRetry: {}
    )
    .frame(height: 500)
}
