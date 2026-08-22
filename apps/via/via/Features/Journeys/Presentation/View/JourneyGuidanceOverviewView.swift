import SwiftUI

struct JourneyGuidanceOverviewView: View {
  let sections: [JourneySection]

  var body: some View {
    let advice = JourneyGuidanceAdvice.items(for: sections)

    if !advice.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 4) {
          Label("Conseils pour ce trajet", systemImage: "location.viewfinder")
            .font(.title3.weight(.bold))

          Text("Placez-vous au bon endroit et prenez la sortie la plus pratique.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        VStack(spacing: 0) {
          ForEach(advice) { item in
            JourneyGuidanceAdviceRow(item: item)

            if item.id != advice.last?.id {
              Divider()
                .padding(.leading, 58)
            }
          }
        }
        .padding(.horizontal, 14)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
      }
    }
  }
}

private struct JourneyGuidanceAdviceRow: View {
  let item: JourneyGuidanceAdvice

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: item.systemImage)
        .font(.headline.weight(.semibold))
        .foregroundStyle(item.tint)
        .frame(width: 38, height: 38)
        .background(item.tint.opacity(0.12), in: Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 5) {
        Text(item.eyebrow)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        Text(item.title)
          .font(.headline)

        Text(item.detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 14)
    .accessibilityElement(children: .combine)
  }
}

private struct JourneyGuidanceAdvice: Identifiable {
  enum Kind {
    case boarding
    case exit
  }

  let id: String
  let kind: Kind
  let eyebrow: String
  let title: String
  let detail: String

  var systemImage: String {
    switch kind {
    case .boarding: "train.side.front.car"
    case .exit: "figure.walk.departure"
    }
  }

  var tint: Color {
    switch kind {
    case .boarding: .accentColor
    case .exit: .green
    }
  }

  static func items(for sections: [JourneySection]) -> [JourneyGuidanceAdvice] {
    sections.flatMap { section in
      var items: [JourneyGuidanceAdvice] = []

      if let position = section.boardingPosition {
        let routeName = section.route.map { "\($0.mode.displayName) \($0.shortName)" }
          ?? "Transport"
        let purpose = switch position.reason {
        case .exit: "pour être près de la sortie"
        case .transfer: "pour votre correspondance"
        }
        let equipment = switch position.equipment {
        case .escalator: " via l’escalator"
        case .lift: " via l’ascenseur"
        case .stairs: " via l’escalier"
        case nil: ""
        }

        items.append(
          JourneyGuidanceAdvice(
            id: "\(section.id):boarding",
            kind: .boarding,
            eyebrow: "Où monter · \(routeName)",
            title: "\(position.zone.title) · voiture \(position.car) sur \(position.carCount)",
            detail: "À \(section.from.name), \(purpose)\(equipment)."
          )
        )
      }

      if let exit = section.exit {
        let title = exit.number.map { "Sortie \($0)" } ?? "Sortie recommandée"
        let distance = exit.walkingMeters.map { meters in
          let rounded = max(50, (meters + 25) / 50 * 50)
          return " · environ \(rounded) m"
        } ?? ""

        items.append(
          JourneyGuidanceAdvice(
            id: "\(section.id):exit",
            kind: .exit,
            eyebrow: "À l’arrivée · \(section.to.name)",
            title: title,
            detail: "\(exit.name)\(distance) de votre destination."
          )
        )
      }

      return items
    }
  }
}

private extension JourneyBoardingPosition.Zone {
  var title: String {
    switch self {
    case .front: "En tête"
    case .middle: "Au milieu"
    case .rear: "En queue"
    }
  }
}
