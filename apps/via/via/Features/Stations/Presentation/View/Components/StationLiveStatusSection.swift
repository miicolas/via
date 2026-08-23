import SwiftUI

struct StationLiveStatusSection: View {
  let status: StationLiveStatus
  let pendingRecoveryCategory: ReportCategory?
  let onRecovery: (ReportCategory) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("État en direct")
        .font(.title3.weight(.bold))

      ForEach(status.incidents) { incident in
        statusCard(
          title: incident.label,
          systemImage: incident.state == .recovered
            ? "checkmark.circle.fill" : incident.category.systemImage,
          source: .reported,
          attribution: ReportAttribution.attribution(for: incident),
          observedAt: incident.observedAt,
          expiresAt: incident.expiresAt
        )

        if incident.canReportRecovery {
          recoveryButton(for: incident.category)
        }
      }
    }
    .accessibilityElement(children: .contain)
  }

  private func statusCard(
    title: String,
    systemImage: String,
    source: ReportDataSource,
    attribution: String,
    observedAt: Date?,
    expiresAt: Date?
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: systemImage)
        .font(.headline)

      Text(attribution)
        .font(.caption.weight(.semibold))
        .foregroundStyle(source == .reported ? .orange : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((source == .reported ? Color.orange : Color.secondary).opacity(0.12), in: Capsule())

      if let observedAt {
        Text("Observé \(RelativeTimeFormatting.short(observedAt))")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      if let expiresAt {
        Text("Expire \(RelativeTimeFormatting.short(expiresAt))")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private func recoveryButton(for category: ReportCategory) -> some View {
    Button {
      onRecovery(category)
    } label: {
      Label {
        Text(pendingRecoveryCategory == category ? "Envoi…" : "Fonctionne à nouveau")
      } icon: {
        Image(systemName: pendingRecoveryCategory == category ? "hourglass" : "checkmark.circle")
          .stateSymbolTransition(value: pendingRecoveryCategory == category)
      }
    }
    .secondaryAction()
    .disabled(pendingRecoveryCategory != nil)
    .accessibilityHint("Confirme le rétablissement sans masquer votre identité aux autres voyageurs.")
  }
}
