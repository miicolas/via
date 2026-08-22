import SwiftUI

struct LinesNetworkSummaryView: View {
  var summary: LineNetworkSummary
  var fetchedAt: Date?
  var isRefreshing: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 14) {
        LineConditionBadge(condition: summary.leadingCondition)

        VStack(alignment: .leading, spacing: 4) {
          Text(summary.headline)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)

          Text(summary.detail)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      Divider()

      freshness
    }
    .padding(18)
    .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 22))
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var freshness: some View {
    if isRefreshing {
      LoadingStatus(label: "Actualisation…")
    } else {
      HStack(spacing: 8) {
        if let fetchedAt {
          Image(systemName: "clock")
            .accessibilityHidden(true)
          Text("Mis à jour \(fetchedAt, format: .relative(presentation: .named))")
        } else {
          Image(systemName: "wifi.exclamationmark")
            .accessibilityHidden(true)
          Text("État en temps réel indisponible")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }
}
