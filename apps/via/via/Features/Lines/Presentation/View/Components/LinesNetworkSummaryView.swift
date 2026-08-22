import SwiftUI

/// The verdict on the network, as one status line rather than a card. The lines
/// themselves are what the traveller came for, so the summary spends a single
/// row and hands the screen straight over to them.
struct LinesNetworkSummaryView: View {
  var summary: LineNetworkSummary
  var fetchedAt: Date?
  var isRefreshing: Bool

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: summary.leadingCondition.systemImage)
        .foregroundStyle(summary.leadingCondition.tint)
        .accessibilityHidden(true)

      Text(summary.headline)
        .fontWeight(.semibold)

      if let trailingDetail = summary.trailingDetail {
        Text("· \(trailingDetail)")
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      freshness
    }
    .font(.footnote)
    .lineLimit(1)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(summary.headline). \(summary.detail)")
    .accessibilityValue(freshnessLabel)
  }

  @ViewBuilder
  private var freshness: some View {
    if isRefreshing {
      ProgressView()
        .controlSize(.mini)
        .accessibilityHidden(true)
    } else {
      Label {
        Text(freshnessTitle)
      } icon: {
        Image(systemName: fetchedAt == nil ? "wifi.exclamationmark" : "clock")
      }
      .foregroundStyle(.secondary)
      .accessibilityHidden(true)
    }
  }

  private var freshnessTitle: String {
    guard let fetchedAt else { return "Hors ligne" }
    return RelativeTimeFormatting.short(fetchedAt)
  }

  private var freshnessLabel: String {
    if isRefreshing { return "Actualisation en cours" }
    guard let fetchedAt else { return "État en temps réel indisponible" }
    return "Mis à jour \(RelativeTimeFormatting.spelled(fetchedAt))"
  }
}
