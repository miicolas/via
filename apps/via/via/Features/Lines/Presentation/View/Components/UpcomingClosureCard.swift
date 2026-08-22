import SwiftUI

struct UpcomingClosureCard: View {
  var status: LineStatus

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      LineBadgeView(route: status.route, size: 36)

      VStack(alignment: .leading, spacing: 5) {
        Text(status.upcoming?.title ?? "Fermeture prévue")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)

        if let beginsAt = status.upcoming?.beginsAt {
          Label(
            "À partir de \(beginsAt.formatted(date: .omitted, time: .shortened))",
            systemImage: "clock"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(.orange.opacity(0.08), in: .rect(cornerRadius: 20))
    .accessibilityElement(children: .combine)
  }
}
