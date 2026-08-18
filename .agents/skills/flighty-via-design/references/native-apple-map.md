# Flighty Via — carte de décision Apple natif

Principe : Apple fournit le comportement et l’accessibilité; Via fournit la surface Flighty. Ne remplace pas une API native par un composant dessiné à la main uniquement pour obtenir une couleur ou un rayon.

## Navigation et présentation

| Besoin | Choix Apple | Adaptation Via | Ne pas faire |
| --- | --- | --- | --- |
| Premier niveau | `TabView(selection:)` + `Tab` | Labels français, SF Symbols, `Tab(role: .search)` à droite | Capsule ou barre de tabs dessinée |
| Parcours hiérarchique | `NavigationStack` | Titres, sections et cartes Flighty | Push manuel avec flags dispersés |
| Recherche globale | `Tab(role: .search)` + `searchable` ou `TextField` natif | Tokens, prompt, results rows | Ancienne search toolbar persistante |
| Action secondaire | `Menu` | Label/icone et contenu de menu coloré si utile | Multi-menu profond ou bouton custom déguisé |
| Choix exclusif | `Picker` / `Menu` | Carte ou row sélectionnée si la surface le demande | Réimplémenter un contrôle radio sans raison |
| Action contextuelle | `contextMenu` | Actions secondaires, suppression rapide | Mettre l’unique chemin d’action dans le menu |
| Action destructive | `confirmationDialog` | Copie française et rôle `.destructive` | Confirmation custom non accessible |
| Détail / édition | `sheet`, `popover` | `adaptiveSheetPresentation` existant, surfaces, detents | Refaire la plomberie du sheet |
| Partage | `ShareLink` | Préparer un payload et un label Flighty | Refaire le share sheet système |

## Search and focus

Le champ de recherche doit conserver le focus système, le curseur, le clavier, la sélection et le clear button. Pour l’UX tokenisée :

1. Une `Button` ouvre le champ origine/destination et donne le focus.
2. Une valeur validée est rendue comme un token neutre dans une `HStack`/`LabeledContent`.
3. Le `TextField` actif reçoit le focus via `@FocusState`, une taille de texte lisible et un bouton clear à 44 points.
4. Les résultats sont des `Button` rows avec un label vocal complet; la sélection déclenche l’intention du modèle.
5. La recherche en langage naturel partage le même flux mais n’est pas convertie en faux code d’aéroport.

Le clavier n’est pas caché par une animation custom. Si un toolbar clavier est utile, utiliser `.toolbar(placement: .keyboard)`.

## Maps

- Utiliser `Map`/`MapReader`/`Map(selection:)`, `Marker`, `Annotation`, `MapUserLocationButton`, `MapCompass` et les contrôles de caméra disponibles.
- Les annotations de station doivent déclarer une sélection native avant d’envisager un gesture.
- Les surfaces et overlays peuvent utiliser `safeAreaInset`, `overlay(alignment:)` et le sheet existant; ne pas bloquer toute la carte avec une vue transparente interactive.

## Sheets

Le contrat actuel est conservé : detents compacts/large écran, background interaction, largeur, corner radius wide screen, drag indicator et dismiss policy. Une nouvelle feature ne manipule que son contenu et sa route. Utiliser `presentationDetents`, `presentationBackgroundInteraction`, `presentationContentInteraction` et `interactiveDismissDisabled` au niveau de l’adapter existant.

## Controls and accessibility

- `Button` pour toute action; `role: .destructive` pour supprimer.
- `Toggle` pour préférences binaires, jamais un état couleur-only.
- `DatePicker` pour dates/heures; ne pas créer un calendrier custom sans exigence métier.
- `ProgressView` pour une attente indéterminée; skeleton custom uniquement quand il conserve la géométrie Flighty.
- `Label`, `accessibilityLabel`, `accessibilityValue`, `accessibilityHint` et `accessibilityAddTraits(.isSelected)` pour les cartes sélectionnables.
- Les icônes décoratives sont masquées de VoiceOver; les icon-only buttons ont un label.
- Dynamic Type doit pouvoir agrandir les titres et descriptions sans tronquer l’action principale.
- `@Environment(\.accessibilityReduceMotion)` doit commander le beam et toute animation ajoutée.

## Custom boundary

Le custom est justifié pour :

- surfaces, cartes, rows, badges de lignes et statuts;
- empty/loading/error states;
- tokens visuels et choix d’alerte;
- badge PRO;
- beam CTA et adaptation visuelle des sheets.

Le custom n’est pas justifié pour :

- tab bar, navigation stack, menus, confirmation, share sheet, toggles, date pickers, focus/keyboard, MapKit selection;
- l’algorithme de retour à l’onglet précédent après Recherche : c’est de l’état de shell (`previousTab`), pas une tab bar redessinée.

## Official references

- [TabView and tab navigation](https://developer.apple.com/documentation/swiftui/enhancing-your-app-content-with-tab-navigation)
- [TabRole.search](https://developer.apple.com/documentation/swiftui/tabrole/search)
- [Human Interface Guidelines — Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [Human Interface Guidelines — Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields)
- [Menus and commands](https://developer.apple.com/documentation/swiftui/menus-and-commands/)
- [Modal presentations](https://developer.apple.com/documentation/swiftui/modal-presentations)
