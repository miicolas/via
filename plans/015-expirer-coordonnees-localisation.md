# Plan 015 : Expirer les coordonnées de localisation avant recherche et planification

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « Conditions STOP » se produit, arrêter et remonter le problème
> sans improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/via/via/Shared/Location/LocationService.swift apps/via/viaTests/LocationModelTests.swift apps/via/viaTests/SearchViewModelTests.swift`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : M (environ une journée avec les tests d’horloge et de planification)
- **Risque** : MED — le cache est partagé par carte, stations, recherche et trajet
- **Dépend de** : `plans/002-restaurer-baseline-tests-ios.md`
- **Catégorie** : bug
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

`LocationModel` conserve une coordonnée sans son heure d’acquisition. Toute
lecture future de `coordinate` la considère donc valable, même plusieurs heures
après un déplacement. La recherche de proximité peut être biaisée et
« Ma position » peut planifier un trajet depuis l’ancien quartier sans demander
une nouvelle mesure.

Le modèle doit conserver le `LocationSample` horodaté, exposer une coordonnée
uniquement pendant une fenêtre courte et demander un nouveau fix lorsqu’un
trajet utilise une valeur expirée. La correction reste dans le propriétaire
partagé de Core Location afin que tous les consommateurs appliquent la même
règle.

## État actuel

### Fichiers et responsabilités

- `apps/via/via/Shared/Location/LocationService.swift` — modèle partagé, événements d’adapter et implémentations Core Location / mémoire.
- `apps/via/viaTests/LocationModelTests.swift` — tests du cache, des permissions, du timeout et du suivi continu.
- `apps/via/viaTests/SearchViewModelTests.swift` — caractérise la résolution de « Ma position » avant la requête trajet.

### Extraits à reconnaître avant modification

`LocationService.swift:13-31` possède déjà un échantillon horodaté pour le
suivi, mais pas pour le fix ponctuel :

```swift
enum LocationState: Sendable, Equatable {
    case idle(authorization: LocationAuthorization)
    case locating
    case located(GeoCoordinate)
    case failed(LocationAuthorization)
}

enum LocationAdapterEvent: Sendable, Equatable {
    case authorizationChanged(LocationAuthorization)
    case located(GeoCoordinate)
    case updated(LocationSample)
    case failed(LocationAuthorization)
}

struct LocationSample: Codable, Sendable, Equatable {
    let coordinate: GeoCoordinate
    let horizontalAccuracy: Double?
    let recordedAt: Date
}
```

`LocationService.swift:73-75,95-102` retourne toujours la valeur en mémoire :

```swift
var coordinate: GeoCoordinate? {
    guard case .located(let coordinate) = state else { return nil }
    return coordinate
}

func requestCurrentLocation() async -> GeoCoordinate? {
    if let coordinate { return coordinate }
    return await requestFreshLocation()
}
```

Le delegate possède pourtant le timestamp natif et le vérifie déjà à
`LocationService.swift:340-357` :

```swift
guard let value = locations.last else { return }
// ...
} else if isLocatingOnce,
          value.timestamp >= Date.now.addingTimeInterval(-Self.maximumCachedLocationAge) {
    manager.stopUpdatingLocation()
    isLocatingOnce = false
    onEvent?(.located(coordinate))
}
```

`SearchViewModel.swift:1217-1223` est déjà structuré pour rafraîchir
« Ma position » si `requestCurrentLocation()` ne renvoie pas le cache :

```swift
private func resolveOrigin() async -> GeoCoordinate? {
  switch selectedDeparture {
  case .currentLocation:
    await locationModel.requestCurrentLocation()
  case .saved, .savedDestination, .manual:
    selectedDeparture.coordinate
  }
}
```

Les recherches de proximité lisent directement `locationModel.coordinate`, par
exemple à `SearchViewModel.swift:1230-1234`; elles doivent recevoir `nil` plutôt
qu’une coordonnée expirée. Ne déclenchez pas une demande de permission ou de
GPS sur chaque frappe.

### Règle de fraîcheur cible

- Une coordonnée partagée est réutilisable pendant **60 secondes**.
- Une horloge injectée décide de l’âge afin de rendre les tests déterministes.
- Un échantillon daté de plus de 5 secondes dans le futur est rejeté, comme le
  garde-fou du suivi actif (`ActiveJourneyModel.isLocationUsable`).
- La limite de 15 secondes du `CoreLocationAdapter` reste la règle d’acceptation
  d’un événement fourni par Core Location ; la limite de 60 secondes est la
  durée de réutilisation par les fonctionnalités après acceptation.

## Commandes utiles

| But                | Commande                                                                                                                                                                                                                                                           | Résultat attendu         |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------ |
| Tests localisation | `xcodebuild -quiet -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' -only-testing:ViaTests/LocationModelTests test`   | exit 0                   |
| Tests recherche    | `xcodebuild -quiet -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' -only-testing:ViaTests/SearchViewModelTests test` | exit 0                   |
| Suite complète     | `IOS_TEST_DESTINATION='platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' VIA_API_CLIENT_KEY=improve-audit-placeholder bun run test:ios`                                                                                                              | exit 0 après le plan 002 |
| Build              | `xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'generic/platform=iOS Simulator' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' build`                                                                                   | `BUILD SUCCEEDED`        |

## Périmètre

### Fichiers autorisés

- `apps/via/via/Shared/Location/LocationService.swift`
- `apps/via/viaTests/LocationModelTests.swift`
- `apps/via/viaTests/SearchViewModelTests.swift`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `ActiveJourneyModel` et sa règle de fraîcheur de suivi continu : il consomme
  déjà `LocationSample.recordedAt` et possède une politique différente.
- L’UX de permission et les empty states.
- Les algorithmes de recherche, de distance et de planification serveur.
- Le rafraîchissement automatique de la carte à l’instant précis où le TTL
  expire : ce plan garantit la fraîcheur au prochain accès métier.
- Une persistance disque des coordonnées ; le cache reste strictement mémoire.

## Git

- Branche recommandée : `codex/015-expire-location-cache`.
- Commit suggéré : `fix(ios): expire cached location fixes`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Caractériser l’expiration avec une horloge contrôlée

Dans `LocationModelTests.swift`, ajouter une petite horloge test thread-safe et
un adapter de test mutable capable d’émettre un `LocationSample` avec une date
choisie. Ajouter les cas suivants :

1. un échantillon âgé de 59 secondes reste exposé par `model.coordinate` et
   `requestCurrentLocation()` ne redemande pas de fix ;
2. à 61 secondes, `model.coordinate` vaut `nil` ;
3. `requestCurrentLocation()` redemande alors au même adapter une mesure et
   retourne sa nouvelle coordonnée ; le compteur de demandes passe de 1 à 2 ;
4. un échantillon trop futuriste n’est pas réutilisé ;
5. un événement de suivi `.updated(sample)` alimente le même cache horodaté.

Le test d’expiration doit échouer sur le code actuel parce que `coordinate`
retourne encore la première coordonnée et que le compteur reste à 1.

**Vérifier** : lancer uniquement le nouveau test d’expiration → échec attendu
avant le fix sur la valeur stale, sans timeout.

### 2. Conserver le sample du fix ponctuel sans casser `LocationState`

Dans `LocationService.swift` :

- changer `LocationAdapterEvent.located` pour transporter `LocationSample` ;
- conserver `LocationState.located(GeoCoordinate)` afin de ne pas imposer le
  timestamp aux vues et à `StationsViewModel` ;
- ajouter à `LocationModel` :
  - `lastSample: LocationSample?` ignoré par Observation ;
  - une closure `now: @Sendable () -> Date`, injectée avec défaut `{ .now }` ;
  - une durée injectée ou une constante nommée de 60 secondes ;
- quand un événement `.located(sample)` ou `.updated(sample)` est accepté,
  enregistrer le sample puis publier `.located(sample.coordinate)` ;
- rendre `coordinate` dépendant de `lastSample` et de la fenêtre
  `age >= -5 && age <= 60` ;
- vider le sample lorsque l’autorisation devient `.denied` ou `.restricted` ;
  une erreur transitoire de localisation ne doit pas rendre frais un sample,
  mais sa date naturelle continuera de l’expirer.

Ne pas démarrer de timer pour muter `state` au bout de 60 secondes. La lecture
fraîche de `coordinate` est la frontière métier et évite un task de durée de
vie supplémentaire.

**Vérifier** : `LocationModelTests` → tous les tests passent, y compris les
tests existants de permission, timeout et suivi.

### 3. Propager le timestamp réel depuis chaque adapter

Dans `CoreLocationAdapter.locationManager(_:didUpdateLocations:)`, construire
un unique `LocationSample` depuis :

- la coordonnée native ;
- `horizontalAccuracy` lorsqu’elle est positive ;
- `value.timestamp`.

Réutiliser ce sample pour `.updated` et `.located`. Conserver la garde native
de 15 secondes avant l’émission ponctuelle.

Dans `InMemoryLocationAdapter.requestLocation()`, émettre un sample daté au
moment de la demande avec son `horizontalAccuracy`. Adapter les fakes de
`LocationModelTests` à la nouvelle signature ; n’utiliser `.now` dans un fake
que pour les tests qui ne contrôlent pas le temps.

**Vérifier** :

```bash
rg -n 'case located\(LocationSample\)|recordedAt: value\.timestamp' \
  apps/via/via/Shared/Location/LocationService.swift
```

Résultat attendu : le contrat d’événement et le timestamp Core Location sont
présents ; aucune émission `.located(coordinate)` ne subsiste.

### 4. Prouver qu’une planification « Ma position » rafraîchit le cache

Dans `SearchViewModelTests.swift`, suivre la structure de
`testCurrentLocationFailureBlocksOnlyTheCurrentOrigin` et utiliser
`JourneyRepositoryRecorder` :

1. initialiser `LocationModel` avec l’horloge et l’adapter contrôlables ;
2. acquérir une première coordonnée ;
3. avancer l’horloge de 61 secondes et configurer une seconde coordonnée ;
4. sélectionner une destination avec le départ `.currentLocation` par défaut ;
5. attendre `.results` ;
6. affirmer que la requête de trajet utilise la seconde coordonnée et que
   l’adapter a reçu une deuxième demande.

Ajouter aussi une assertion directe démontrant qu’une recherche de proximité
voit `nil` pendant l’intervalle entre expiration et nouvelle acquisition, sans
déclencher elle-même une demande GPS.

**Vérifier** : `SearchViewModelTests` → exit 0 et la requête enregistrée a pour
origine la coordonnée fraîche.

### 5. Exécuter toute la non-régression iOS

**Vérifier** : exécuter :

```bash
IOS_TEST_DESTINATION='platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' \
  VIA_API_CLIENT_KEY=improve-audit-placeholder \
  bun run test:ios
xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  'VIA_API_CLIENT_KEY=improve-audit-placeholder' build
```

Résultat attendu : suite complète et build à exit 0.

## Plan de test

- Fraîcheur juste avant et juste après la limite de 60 secondes.
- Rejet d’un timestamp anormalement futur.
- Un cache frais évite une seconde requête adapter.
- Un cache expiré force une seconde acquisition pour `requestCurrentLocation()`.
- Les fixes ponctuels et les samples de suivi alimentent la même source de date.
- La planification classique « Ma position » envoie la coordonnée renouvelée.
- Une recherche de proximité n’envoie jamais la coordonnée expirée et ne
  sollicite pas le GPS à chaque frappe.
- Les tests existants de permission refusée et de timeout restent inchangés.

## Critères de fin

- [ ] Tout événement ponctuel conserve `recordedAt` et `horizontalAccuracy` depuis Core Location.
- [ ] `LocationModel.coordinate` vaut `nil` au-delà de 60 secondes ou pour un timestamp trop futur.
- [ ] `requestCurrentLocation()` réutilise un sample frais et renouvelle un sample expiré.
- [ ] `LocationState` conserve sa forme publique actuelle pour les vues.
- [ ] La planification « Ma position » utilise la nouvelle mesure dans le test de régression.
- [ ] La recherche de proximité ne reçoit jamais une coordonnée expirée.
- [ ] Les tests `LocationModelTests`, `SearchViewModelTests`, la suite complète et le build passent.
- [ ] Aucun fichier hors périmètre n’est modifié, hors statut de l’index.

## Conditions STOP

Arrêter et remonter le problème si :

- le produit dispose déjà d’une autre politique documentée de fraîcheur pour
  recherche/planification ; ne pas introduire deux TTL concurrents ;
- transporter `LocationSample` exige de modifier des DTO réseau ou la
  persistance : ces couches ne doivent pas connaître le cache Core Location ;
- la planification contourne `requestCurrentLocation()` après dérive du code ;
- le nouveau test ne reproduit pas l’utilisation de l’ancienne coordonnée ;
- le changement déclenche une demande de permission ou de GPS à chaque frappe
  de recherche ;
- un test de suivi actif échoue, notamment sur les samples antérieurs à la session ;
- un changement demande de toucher un fichier hors périmètre ;
- une vérification échoue deux fois après une correction raisonnable.

## Notes de maintenance

- Toute nouvelle fonctionnalité qui lit `LocationModel.coordinate` obtient par
  construction une valeur fraîche ou `nil`; elle ne doit pas mémoriser la
  coordonnée séparément sans timestamp.
- La fenêtre de 60 secondes est une politique produit partagée. Si elle change,
  modifier une seule constante et garder les tests de frontière explicites.
- En review, vérifier la provenance de `recordedAt` : le delegate doit conserver
  `CLLocation.timestamp`, pas remplacer toutes les dates par l’heure de réception.
- Un futur rafraîchissement proactif au passage en foreground peut améliorer la
  première frame de carte, mais il n’est pas nécessaire pour empêcher une
  mauvaise origine de recherche ou de trajet.
