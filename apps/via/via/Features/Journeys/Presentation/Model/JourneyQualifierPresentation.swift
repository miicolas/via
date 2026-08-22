import SwiftUI

/// How a qualifier reads on screen. It hangs off the domain value itself, so
/// the search list and the journey detail cannot mark the same journey with a
/// different word, glyph or colour.
extension Journey.Qualifier {
  var displayName: LocalizedStringResource {
    switch self {
    case .recommended: "Recommandé"
    case .rapid: "Le plus rapide"
    case .lessWalking: "Moins de marche"
    case .comfort: "Le plus simple"
    case .walking: "À pied"
    }
  }

  var systemImage: String {
    switch self {
    case .recommended: "sparkles"
    case .rapid: "hare.fill"
    case .lessWalking: "figure.walk"
    case .comfort: "arrow.forward"
    case .walking: "figure.walk"
    }
  }

  var color: Color {
    switch self {
    case .recommended: .accentColor
    case .rapid: .green
    case .lessWalking: .indigo
    case .comfort: .cyan
    case .walking: .secondary
    }
  }
}
