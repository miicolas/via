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
    .foregroundStyle(isFavorite ? .orange : .secondary)
    .stateSymbolTransition(value: isFavorite)
    .toggleHaptic(on: isFavorite)
    .frame(width: 44, height: 44)
    .contentShape(Rectangle())
    .accessibilityLabel(
      isFavorite
        ? "Retirer la ligne " + route.shortName + " des favoris"
        : "Ajouter la ligne " + route.shortName + " aux favoris"
    )
    .accessibilityValue(isFavorite ? "Ajoutée" : "Non ajoutée")
    .accessibilityHint("Affiche la ligne en accès rapide en haut de l’onglet Lignes.")
  }
}
