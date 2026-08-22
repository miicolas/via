import SwiftUI

struct NetworkMapStatusView: View {
  var loading: NetworkMapLoadingState
  var hasContent: Bool
  var onRetry: () -> Void

  var body: some View {
    VStack {
      switch loading {
      case .loading where !hasContent:
        LoadingStatus(label: "Chargement de la carte…")
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(.regularMaterial, in: .capsule)
      case .failed:
        HStack(spacing: 10) {
          Image(systemName: "wifi.exclamationmark")
            .foregroundStyle(.orange)
            .accessibilityHidden(true)

          Text("Carte indisponible")
            .font(.callout.weight(.semibold))

          RetryButton(action: onRetry)
            .iconAction(size: .small)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
      case .idle, .loading, .loaded:
        EmptyView()
      }
    }
    .frame(maxWidth: .infinity)
  }
}
