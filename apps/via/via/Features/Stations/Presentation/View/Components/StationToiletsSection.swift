import SwiftUI

struct StationToiletsSection: View {
  let toilets: StationToilets

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label {
        Text(toilets.label)
      } icon: {
        Image(systemName: "toilet")
      }
      .font(.headline)

      if let detail = toilets.detail, !detail.isEmpty {
        Text(detail)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: .rect(cornerRadius: 20))
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  StationToiletsSection(
    toilets: StationToilets(
      label: "Sanitaires disponibles",
      detail: "Accès gratuit · Accessible PMR\nÀ proximité de la sortie 3."
    )
  )
  .padding()
}
