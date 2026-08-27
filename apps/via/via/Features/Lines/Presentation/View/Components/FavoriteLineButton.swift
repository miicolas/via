import SwiftUI

struct FavoriteLineButton: View {
  let route: RouteBadge
  let isFavorite: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: StateSymbol.star(isOn: isFavorite))
    }
    .labelStyle(.iconOnly)
    .buttonStyle(.plain)
    .foregroundStyle(isFavorite ? Color.orange : Color.secondary)
    .stateSymbolTransition(value: isFavorite)
    .toggleHaptic(on: isFavorite)
    .frame(width: 44, height: 44)
    .contentShape(Rectangle())
    .accessibilityLabel(accessibilityTitle)
    .accessibilityValue(isFavorite ? "Ajoutée" : "Non ajoutée")
    .accessibilityHint("Affiche la ligne en accès rapide en haut de l’onglet Lignes.")
  }

  private var accessibilityTitle: String {
    if isFavorite {
      "Retirer la ligne \(route.shortName) des favoris"
    } else {
      "Ajouter la ligne \(route.shortName) aux favoris"
    }
  }
}
