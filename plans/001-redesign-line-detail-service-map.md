# Plan 001: Rendre le plan de ligne et ses travaux immédiatement lisibles

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat df7cd3b..HEAD -- apps/via/via/Features/Lines/Presentation apps/via/viaTests/LineDetailViewModelTests.swift apps/via/viaTests/LineSchemaLayoutTests.swift`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : M (environ 1 à 2 jours, previews et accessibilité comprises)
- **Risque** : MED — refonte de composition SwiftUI sans changement de contrat métier
- **Dépend de** : aucun autre plan
- **Catégorie** : direction / UI
- **Planifié au commit** : `df7cd3b`, 2026-08-19

## Pourquoi

Le détail actuel présente le statut, un picker isolé, le schéma, puis les
travaux dans des sections `List` visuellement équivalentes. Le schéma montre
bien les segments interrompus, mais sa légende est implicite et les cartes de
travaux n’affichent pas clairement les stations qui bornent chaque impact.
L’utilisateur doit donc déduire seul le lien entre le texte et le trait pointillé.

La cible conserve le vocabulaire visuel actuel de Via, mais transforme le
schéma en surface principale, calme et aérée : direction, résumé des travaux,
légende et ligne vivent dans une même grande carte. Les détails des travaux
viennent ensuite, avec leurs tronçons affectés placés avant le texte éditorial.
« Map » signifie ici **plan schématique de la ligne**, pas carte géographique :
le modèle `LineDetail` ne contient pas de coordonnées MapKit.

## État actuel

### Fichiers et responsabilités

- `apps/via/via/Features/Lines/Presentation/View/LineDetailView.swift` — compose tout le détail dans une `List`.
- `apps/via/via/Features/Lines/Presentation/View/Components/LineSchemaView.swift` — rend les rows du plan vertical.
- `apps/via/via/Features/Lines/Presentation/View/Components/LineSchemaStopRow.swift` — dessine rail, station et pictogramme de perturbation.
- `apps/via/via/Features/Lines/Presentation/View/Components/LineSchemaCollapsedRow.swift` — replie les séquences de stations saines.
- `apps/via/via/Features/Lines/Presentation/View/Components/LineDisruptionCard.swift` — affiche statut, titre, message et dates, mais pas `impactedSections`.
- `apps/via/via/Features/Lines/Domain/LineSchemaLayout.swift` — projette déjà correctement les perturbations actives sur les tronçons.
- `apps/via/viaTests/LineSchemaLayoutTests.swift` — caractérise les tronçons touchés, chevauchements, branches et perturbations futures.

### Extraits à reconnaître avant modification

`LineDetailView.swift:12-46` place tous les contenus au même niveau :

```swift
List {
    headerSection
    // picker de direction
    Section("Schéma de la ligne") { LineSchemaView(...) }
    Section("En cours") { /* LineDisruptionCard */ }
    Section("À venir") { /* LineDisruptionCard */ }
}
```

`LineSchemaStopRow.swift:9-11` produit un rendu dense :

```swift
private let railWidth: CGFloat = 6
private let beadSize: CGFloat = 14
private let rowHeight: CGFloat = 34
```

`LineDisruptionCard.swift:7-30` affiche le message avant toute information de
localisation et n’utilise jamais `disruption.impactedSections`.

### Contraintes de conception à conserver

- iOS 26, Swift 6 strict concurrency, SwiftUI natif uniquement.
- Un fichier Swift possède une vue primaire ; extraire toute nouvelle vue
  secondaire réutilisable dans un fichier PascalCase distinct.
- Toute action reste un `Button`, `Picker` ou autre contrôle SwiftUI natif avec
  une cible d’au moins 44 points.
- La couleur ne porte jamais seule l’état : conserver texte, icône et motif
  pointillé pour les travaux.
- Les surfaces Via utilisent des fonds secondaires très légers, un rayon de
  18–24 points, 16–20 points de padding et pas de contour dur par défaut.
- Dynamic Type doit pouvoir faire passer les noms de stations sur plusieurs
  lignes ; ne pas conserver de `lineLimit(1)`.
- Ne pas modifier `LineSchemaLayout` ni les modèles/API tant que les règles de
  projection existantes suffisent.

## Commandes utiles

| But | Commande | Résultat attendu |
| --- | --- | --- |
| Build iOS | `bun run ios` | exit 0, `BUILD SUCCEEDED` |
| Build tests | `xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'generic/platform=iOS Simulator' build-for-testing` | exit 0, `TEST BUILD SUCCEEDED` |
| Lister les simulateurs | `xcodebuild -project apps/via/via.xcodeproj -scheme via -showdestinations` | au moins une destination iOS Simulator |
| Tests ciblés | `xcodebuild -project apps/via/via.xcodeproj -scheme via -destination '<destination iOS 26 disponible>' -only-testing:ViaTests/LineSchemaLayoutTests -only-testing:ViaTests/LineDetailViewModelTests test` | tous les tests passent |

La machine ayant servi à écrire ce plan ne dispose pas d’un toolchain Xcode
sélectionné (`xcrun simctl` indisponible). L’exécuteur doit remplacer
`<destination iOS 26 disponible>` par la chaîne exacte retournée par
`-showdestinations`, sans inventer un nom de simulateur.

## Outils conseillés à l’exécuteur

- Lire et appliquer `.agents/skills/flighty-via-design/SKILL.md` avant toute modification SwiftUI.
- Utiliser les previews Xcode pour vérifier les variantes travaux actifs,
  travaux futurs, état normal, mode sombre et grande taille de texte.

## Périmètre

### Fichiers autorisés

- `apps/via/via/Features/Lines/Presentation/View/LineDetailView.swift`
- `apps/via/via/Features/Lines/Presentation/View/Components/LineDetailHeaderView.swift` (nouveau)
- `apps/via/via/Features/Lines/Presentation/View/Components/LineServiceMapCard.swift` (nouveau)
- `apps/via/via/Features/Lines/Presentation/View/Components/LineSchemaLegend.swift` (nouveau)
- `apps/via/via/Features/Lines/Presentation/View/Components/LineDisruptionImpactView.swift` (nouveau)
- `apps/via/via/Features/Lines/Presentation/View/Components/LineDisruptionsSection.swift` (nouveau)
- `apps/via/via/Features/Lines/Presentation/View/Components/LineDisruptionCard.swift`
- `apps/via/via/Features/Lines/Presentation/View/Components/LineSchemaView.swift`
- `apps/via/via/Features/Lines/Presentation/View/Components/LineSchemaStopRow.swift`
- `apps/via/via/Features/Lines/Presentation/View/Components/LineSchemaCollapsedRow.swift`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `LineSchemaLayout`, `LineDetailModels`, les DTO, repositories et endpoints :
  aucune donnée supplémentaire n’est nécessaire à cette refonte.
- `NetworkMapView` et toute carte géographique MapKit.
- La liste globale des lignes, le détail station, la navigation principale et
  les feuilles adaptatives.
- Une sélection interactive d’un travail qui filtre ou recentre le schéma :
  cela ajouterait un nouvel état produit non demandé.
- Toute nouvelle dépendance, tout changement de couleur métier ou toute
  animation décorative permanente.

## Git

- Branche recommandée : `codex/001-line-detail-service-map`.
- Utiliser le style de commits observé, par exemple
  `feat(ios): clarify line works on the service map`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Recomposer l’écran autour d’une hiérarchie unique

Dans `LineDetailView`, remplacer la `List` de sections équivalentes par un
`ScrollView` contenant un `LazyVStack(alignment: .leading, spacing: 28)` et une
marge horizontale de 16–20 points. Garder sans modification comportementale :

- `.refreshable { await viewModel.refresh() }` ;
- `.task { await viewModel.runAutomaticRefresh() }` ;
- le titre de navigation inline ;
- les overlays loading/error existants ;
- le binding de direction et `toggleRun`.

Ordre cible :

1. `LineDetailHeaderView` ;
2. `LineServiceMapCard` ;
3. section `Travaux en cours` si nécessaire ;
4. section `Travaux à venir` si nécessaire.

Le fond de page doit être un grouped background système. Les surfaces doivent
rester adaptatives en clair/sombre, avec un fond presque opaque, un rayon de 24
et une ombre très douce ; ne pas utiliser de matériau translucide qui réduise
le contraste.

Créer `LineDetailHeaderView` avec une interface étroite : `route`, `condition`,
`source` et `fetchedAt`. Afficher le badge 44 points, le statut textuel et la
fraîcheur des données. Le composant ne charge rien et ne possède aucun état.

**Vérifier** : `bun run ios` → `BUILD SUCCEEDED`.

### 2. Faire du plan de ligne la surface principale

Créer `LineServiceMapCard` avec les seules entrées nécessaires :

- direction sélectionnée et toutes les directions ;
- binding de sélection ;
- rows de `LineSchemaLayout` ;
- couleur de ligne ;
- perturbations actives ;
- closure `onToggleRun`.

Composition interne, de haut en bas :

1. titre `Plan de la ligne` ;
2. `Picker` menu intégré à la carte, libellé `Direction`, valeur visible
   `Vers <terminus>` ; cible verticale minimale de 44 points ;
3. si travaux actifs, un encart compact teinté par la pire sévérité :
   `N travaux en cours` + résumé des bornes (`A → B`) provenant de
   `impactedSections` ; limiter le résumé à deux tronçons puis afficher
   `+ N autres` pour éviter une carte démesurée ;
4. `LineSchemaLegend` expliquant explicitement `Service normal` (trait plein)
   et `Travaux / interruption` (trait pointillé + symbole) ;
5. `LineSchemaView`.

Le `Picker` existant disparaît de sa section isolée. En état normal, ne pas
réserver de vide à l’encart de travaux. La carte doit rester lisible avec une
seule direction et ne pas afficher de menu inutile dans ce cas : montrer
simplement `Vers <terminus>` comme texte secondaire.

**Vérifier** : `bun run ios` → `BUILD SUCCEEDED` et aucune occurrence de
`Section("Schéma de la ligne")` dans `LineDetailView.swift`.

### 3. Aérer et expliciter le tracé

Dans `LineSchemaStopRow` :

- porter la hauteur minimale d’une station autour de 42–46 points, sans hauteur
  fixe qui coupe Dynamic Type ; utiliser `minHeight` et padding vertical ;
- réduire légèrement le rail plein (environ 4 points) et agrandir les perles
  importantes (terminus ou station touchée) ;
- supprimer `lineLimit(1)` et permettre le wrapping naturel du nom ;
- derrière une station touchée, ajouter un wash sémantique très léger (environ
  8–12 % de la teinte) sur la zone texte, avec rayon généreux ;
- conserver le rail pointillé et le pictogramme d’avertissement, afin que la
  couleur ne soit jamais le seul signal ;
- formuler une valeur VoiceOver qui nomme l’état (`Perturbée`, `Suspendue`, etc.)
  au lieu de la phrase générique actuelle.

Adapter `LineSchemaCollapsedRow` à la même respiration et garantir une cible
`Button` de 44 points. Garder le trait continu dans le repli et le label vocal
existant. Dans `LineSchemaView`, ajouter uniquement les espacements nécessaires
entre branches ; ne dupliquer ni légende ni fond de carte.

**Vérifier** :
`xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'generic/platform=iOS Simulator' build-for-testing`
→ `TEST BUILD SUCCEEDED`.

### 4. Mettre la localisation du travail avant son récit

Créer `LineDisruptionImpactView`, vue sans état recevant
`[LineImpactedSection]`. Pour chaque tronçon, afficher une row compacte : icône
de réseau/branche, `fromName`, une flèche, puis `toName`. Si les bornes sont
identiques ou absentes, dégrader proprement vers `Zone concernée non précisée`
plutôt que d’afficher une flèche vide. Combiner chaque row en un élément
VoiceOver du type `Entre A et B`.

Recomposer `LineDisruptionCard` dans cet ordre :

1. statut textuel + capsule `En cours` ou `À venir` ;
2. titre ;
3. `LineDisruptionImpactView` ;
4. période avec icône calendrier ;
5. message explicatif ;
6. heure de mise à jour, visuellement tertiaire.

Appliquer un fond sémantique très léger aux travaux actifs et un fond secondaire
neutre aux travaux futurs. Ne pas utiliser de bordure rouge/orange dure. Ne pas
cacher le message derrière un `DisclosureGroup` : l’impact doit rester lisible
sans interaction supplémentaire. Préserver `accessibilityElement(children:
.combine)` seulement si cela ne transforme pas une longue carte multi-tronçons
en une annonce inexploitable ; sinon regrouper par sous-blocs.

**Vérifier** : `bun run ios` → `BUILD SUCCEEDED`, puis rechercher
`impactedSections` dans `LineDisruptionCard.swift` ou
`LineDisruptionImpactView.swift` → au moins une utilisation de rendu.

### 5. Ajouter des previews de validation visuelle

Dans les fichiers de vues concernés, fournir des previews nommées couvrant au
minimum :

- Métro 1 avec travaux actifs ;
- RER A avec branches et plusieurs tronçons ;
- ligne sans perturbation ;
- travaux futurs uniquement ;
- mode sombre ;
- Dynamic Type `accessibility2`.

Réutiliser exclusivement `PreviewLineStatusRepository`; ne pas dupliquer une
grosse fixture dans le code de présentation. Vérifier dans les previews que :

- le plan est visible avant les longs messages de travaux ;
- le sens du plein/pointillé est explicite sans deviner ;
- chaque carte de travail nomme ses stations de début et de fin ;
- les noms longs passent sur plusieurs lignes sans collision avec les icônes ;
- l’absence de travaux ne laisse pas de trou ;
- aucune information n’est portée par la couleur seule.

**Vérifier** : `bun run ios` → `BUILD SUCCEEDED`.

### 6. Exécuter la non-régression métier

Ne pas modifier les attentes de tests existantes pour faire passer la refonte.
Les tests de `LineSchemaLayoutTests` doivent confirmer que le trait pointillé
continue de suivre les bons tronçons, épargne les branches parallèles, garde la
pire sévérité et ignore les travaux futurs. Les tests du view model doivent
confirmer que le choix de direction et le pliage/dépliage restent stables.

**Vérifier** : remplacer la destination dans la commande ci-dessous avec la
valeur exacte de `-showdestinations`, puis exécuter :

```bash
xcodebuild -project apps/via/via.xcodeproj -scheme via \
  -destination '<destination iOS 26 disponible>' \
  -only-testing:ViaTests/LineSchemaLayoutTests \
  -only-testing:ViaTests/LineDetailViewModelTests test
```

Résultat attendu : tous les tests ciblés passent, sans modification de leurs
assertions métier.

## Plan de test

- **Tests unitaires nouveaux** : aucun requis si `LineSchemaLayout`, les modèles
  et le view model restent inchangés ; la refonte est purement présentationnelle.
- **Tests de caractérisation existants** : exécuter intégralement
  `LineSchemaLayoutTests` et `LineDetailViewModelTests`.
- **Vérification de compilation** : `bun run ios` et `build-for-testing`.
- **Vérification visuelle manuelle** : les six previews nommées de l’étape 5,
  avec attention particulière au mode sombre, aux noms de station longs et à
  la taille `accessibility2`.
- Si l’implémentation ajoute une transformation non triviale (par exemple le
  résumé `+ N autres`) hors de la vue, ajouter un test unitaire ciblé dans
  `LineDetailViewModelTests.swift`; sinon ne pas élargir le modèle pour tester
  du simple layout.

## Critères de fin

- [ ] `bun run ios` se termine avec `BUILD SUCCEEDED`.
- [ ] Le build-for-testing se termine avec `TEST BUILD SUCCEEDED`.
- [ ] `LineSchemaLayoutTests` et `LineDetailViewModelTests` passent.
- [ ] Le plan de ligne apparaît avant les cartes détaillées de travaux.
- [ ] Direction, résumé des travaux, légende et tracé sont réunis dans une seule surface.
- [ ] Chaque travail avec `impactedSections` affiche explicitement ses bornes.
- [ ] Le trait plein et le trait pointillé sont expliqués textuellement.
- [ ] Les noms de station n’utilisent plus `lineLimit(1)`.
- [ ] Le bouton de stations repliées et le picker de direction offrent au moins 44 points de cible.
- [ ] Les previews couvrent travaux actifs, futurs, normal, branches, sombre et Dynamic Type.
- [ ] Aucun fichier hors du périmètre n’est modifié, à l’exception du statut dans `plans/README.md`.

## Conditions STOP

Arrêter et remonter le problème si :

- le produit attend en réalité une carte géographique : il faut alors ajouter
  un contrat de géométrie et redéfinir le périmètre au lieu de détourner
  `NetworkMapView` ;
- le code de projection ou le payload de détail a structurellement changé
  depuis `df7cd3b` ;
- rendre les bornes lisibles exige de modifier le contrat API ou d’inventer des
  noms de stations absents de `impactedSections` ;
- un changement demande de toucher un fichier hors périmètre ;
- un test métier existant échoue deux fois après correction raisonnable ;
- le `ScrollView.refreshable` ne fonctionne pas sur la cible iOS 26 du projet ;
- Xcode ne propose aucune destination iOS 26 permettant d’exécuter les tests.

## Notes de maintenance

- La projection des travaux sur le tracé reste la responsabilité exclusive de
  `LineSchemaLayout`; les vues ne doivent pas recalculer quels segments couper.
- `LineDisruptionImpactView` affiche les bornes déclarées par la donnée. Elle ne
  doit pas reconstruire un trajet à partir de l’ordre visuel des stations.
- En review, vérifier surtout la lecture sans couleur, le wrapping Dynamic Type
  et la distinction entre travaux actifs et futurs.
- Une future interaction « sélectionner un travail pour surligner son seul
  tronçon » pourra s’ajouter sur cette composition, mais nécessite un état de
  sélection et des identifiants de perturbation projetés dans le layout ; elle
  est explicitement différée.
