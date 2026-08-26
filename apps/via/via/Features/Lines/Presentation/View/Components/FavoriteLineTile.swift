import SwiftUI

/// A compact square quick-access tile for a saved line. The small status mark
/// is deliberately supplemental: the route code remains the primary content,
/// while the combined accessibility value spells out the condition.
struct FavoriteLineTile: View {
  let status: LineStatus

  var body: some View {
    ZStack(alignment: .topTrailing) {
      LineBadgeView(route: status.route, size: 44)

      if let indicatorCondition {
        Image(systemName: indicatorImage)
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(indicatorForeground)
          .frame(width: 18, height: 18)
          .background(indicatorCondition.tint, in: .circle)
          .overlay {
            Circle()
              .stroke(.background, lineWidth: 2)
          }
          .offset(x: 6, y: -6)
      }
    }
    .frame(width: 76, height: 76)
    .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 18))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(status.route.mode.displayName) ligne \(status.route.shortName)")
    .accessibilityValue(accessibilityValue)
    .accessibilityHint("Ouvre le détail de la ligne.")
  }

  private var indicatorCondition: LineCondition? {
    if status.condition != .normal {
      return status.condition
    }

    return status.upcoming == nil ? nil : .attention
  }

  private var indicatorImage: String {
    if status.condition != .normal {
      return status.condition.systemImage
    }

    return "calendar.badge.exclamationmark"
  }

  private var indicatorForeground: Color {
    indicatorCondition == .attention ? .black : .white
  }

  private var accessibilityValue: String {
    if status.condition != .normal {
      return status.condition.title
    }

    if status.upcoming != nil {
      return "Fermeture prévue"
    }

    return LineCondition.normal.title
  }
}

#Preview {
  HStack(spacing: 12) {
    FavoriteLineTile(status: PreviewLineStatusRepository.defaultBoard.lines[0])
    FavoriteLineTile(status: PreviewLineStatusRepository.defaultBoard.lines[2])
  }
  .padding()
}
