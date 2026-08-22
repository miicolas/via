import SwiftUI

struct JourneyExitView: View {
  let exit: JourneyExit
  var isDimmed = false

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "figure.walk.departure")
        .font(.subheadline.weight(.semibold))

      VStack(alignment: .leading, spacing: 1) {
        Text("Sortie recommandée")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)

        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
      }
    }
    .foregroundStyle(.green)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    .opacity(isDimmed ? 0.45 : 1)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private var title: String {
    [heading, distance].compactMap(\.self).joined(separator: " · ")
  }

  private var heading: String {
    guard let number = exit.number else { return exit.name }
    return "Sortie \(number) · \(exit.name)"
  }

  private var distance: String? {
    guard let meters = exit.walkingMeters, meters >= 50 else { return nil }
    return meters >= 1_000
      ? "\((Double(meters) / 1_000).formatted(.number.precision(.fractionLength(1)))) km"
      : "\((meters + 25) / 50 * 50) m"
  }

  var accessibilityLabel: String {
    let number = exit.number.map { "Sortie numéro \($0), " } ?? "Sortie "
    let distance = distance.map { ", à environ \($0) de votre destination" } ?? ""
    return "Sortie recommandée, \(number)\(exit.name)\(distance)"
  }
}
