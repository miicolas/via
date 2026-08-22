import SwiftUI

struct LinesUnavailableBanner: View {
  var body: some View {
    Label(
      "Les dernières données restent affichées. L’état en temps réel est indisponible.",
      systemImage: "wifi.exclamationmark"
    )
    .font(.subheadline)
    .foregroundStyle(.orange)
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(.orange.opacity(0.1), in: .rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}
