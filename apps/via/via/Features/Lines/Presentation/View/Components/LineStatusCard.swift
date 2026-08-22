import SwiftUI

struct LineStatusCard: View {
  var status: LineStatus

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center, spacing: 12) {
        LineBadgeView(route: status.route, size: 42)

        VStack(alignment: .leading, spacing: 3) {
          Text(status.route.mode.displayName)
            .font(.headline)
            .foregroundStyle(.primary)

          LineConditionLabel(
            condition: status.condition,
            font: .caption.weight(.semibold)
          )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      Text(status.summary ?? "Aucune perturbation en cours.")
        .font(.subheadline)
        .foregroundStyle(status.condition == .normal ? .secondary : .primary)
        .fixedSize(horizontal: false, vertical: true)

      if status.activeCount > 1 {
        Label("\(status.activeCount) alertes actives", systemImage: "bell.badge")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let upcoming = status.upcoming {
        UpcomingClosureLabel(closure: upcoming)
      }
    }
    .padding(16)
    .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 20))
    .accessibilityElement(children: .combine)
  }
}
