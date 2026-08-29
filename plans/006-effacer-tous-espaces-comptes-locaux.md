# Plan 006 : Effacer tous les espaces de compte persistés sur l’appareil

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « Conditions STOP » se produit, arrêter et remonter le problème
> sans improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/via/via/Features/Account/Data/AccountLocalStore.swift apps/via/viaTests/AccountModelTests.swift`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : S (quelques heures, tests de persistance compris)
- **Risque** : LOW — suppression bornée au préfixe de stockage Via déjà existant
- **Dépend de** : `plans/002-restaurer-baseline-tests-ios.md`
- **Catégorie** : bug / security
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

L’action « Effacer les données locales » promet de supprimer les profils,
favoris, lieux et recherches de cet appareil. `AccountLocalStore.eraseAll()` ne
supprime pourtant que l’espace anonyme et l’espace actif. Si plusieurs comptes
se sont connectés successivement, les blobs des comptes inactifs restent dans
`UserDefaults` avec leurs noms, préférences et coordonnées enregistrées.

La correction doit supprimer chaque clé appartenant au namespace des espaces
de compte Via, indépendamment du compte actif, tout en conservant les autres
préférences de l’application et les données d’autres bibliothèques.

## État actuel

### Fichiers et responsabilités

- `apps/via/via/Features/Account/Data/AccountLocalStore.swift` — possède le namespace et les opérations atomiques sous `NSLock`.
- `apps/via/viaTests/AccountModelTests.swift` — utilise une suite `UserDefaults` isolée et caractérise déjà deux scénarios d’effacement.

### Extraits à reconnaître avant modification

`AccountLocalStore.swift:7-10` définit un préfixe unique pour tous les espaces :

```swift
private static let legacyRecentsKey = "via.recent-searches.v1"
private static let accountPrefix = "via.account-data.v1."
private static let anonymousKey = "anonymous"
private static let pendingOperationLimit = 500
```

`AccountLocalStore.swift:39-51` ne connaît que deux clés au moment de
l’effacement :

```swift
func eraseAll() {
    locked {
        defaults.removeObject(forKey: Self.legacyRecentsKey)
        defaults.removeObject(forKey: storageKey(for: .anonymous))
        if let activeScope {
            defaults.removeObject(forKey: storageKey(for: activeScope))
        }
        cachedSnapshot = nil
        activeScope = nil
    }
}
```

Chaque utilisateur a pourtant sa propre clé à `AccountLocalStore.swift:273-279` :

```swift
private func storageKey(for scope: AccountScope) -> String {
    switch scope {
    case .anonymous:
        return Self.accountPrefix + Self.anonymousKey
    case .user(let userID):
        return Self.accountPrefix + userID
    }
}
```

`AccountModel.eraseDeviceData()` est déjà le bon propriétaire de la transition
vers un espace anonyme neuf (`AccountModel.swift:84-93`) :

```swift
func eraseDeviceData() {
    synchronizationTask?.cancel()
    synchronizationTask = nil
    store.eraseAll()
    activeScope = nil
    store.deactivate()
    activateAnonymous()
}
```

Il ne faut donc pas déplacer la suppression dans la vue ou l’authentification.
La phrase utilisateur à honorer est dans
`AccountDataSettingsView.swift:127-131` :

```swift
case .eraseDevice:
    "Les profils, favoris, lieux et recherches enregistrés sur cet appareil seront supprimés."
```

### Convention de test à conserver

`AccountModelTests.swift:5-18` crée une suite isolée et détruit son domaine en
`tearDown`. Réutiliser exactement cette isolation ; ne jamais tester
`UserDefaults.standard`.

## Commandes utiles

| But          | Commande                                                                                                                                                                                                                                                        | Résultat attendu                         |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| Tests ciblés | `xcodebuild -quiet -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' -only-testing:ViaTests/AccountModelTests test` | exit 0, tous les tests de compte passent |
| Suite iOS    | `IOS_TEST_DESTINATION='platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' VIA_API_CLIENT_KEY=improve-audit-placeholder bun run test:ios`                                                                                                           | exit 0 après exécution du plan 002       |
| Build        | `xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'generic/platform=iOS Simulator' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' build`                                                                                | exit 0, `BUILD SUCCEEDED`                |

## Périmètre

### Fichiers autorisés

- `apps/via/via/Features/Account/Data/AccountLocalStore.swift`
- `apps/via/viaTests/AccountModelTests.swift`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `AuthSessionViewModel`, le Keychain et les appels de déconnexion serveur : le
  plan 005 traite séparément l’ordre et l’identité des mutations de session.
- `ProfileModel`, `RecentSearchStore` et leurs namespaces propres : la vue les
  efface déjà par leurs propriétaires respectifs.
- Le comportement de déconnexion normale : elle doit continuer à préserver les
  workspaces, comme l’explique le commentaire en tête du store.
- Le format JSON de `AccountLocalSnapshot`, la synchronisation distante et les
  tombstones.
- Toute suppression globale du domaine `UserDefaults`.

## Git

- Branche recommandée : `codex/006-erase-all-account-workspaces`.
- Commit suggéré : `fix(ios): erase every local account workspace`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Ajouter un test qui reproduit la conservation d’un ancien compte

Dans `AccountModelTests.swift`, ajouter un test `@MainActor` qui :

1. crée un `AccountLocalStore` avec `defaults` de la suite de test ;
2. active `user-a`, enregistre un favori ;
3. active `user-b`, enregistre un lieu ou un autre favori ;
4. active de nouveau `user-a`, afin que `user-b` soit un espace **inactif** au
   moment de l’effacement ;
5. ajoute une clé témoin hors namespace, par exemple
   `via.unrelated-test-setting`, avec une valeur connue ;
6. appelle `model.eraseDeviceData()` ;
7. affirme que toutes les clés préexistantes commençant par
   `via.account-data.v1.` ont disparu, y compris `user-b` ;
8. affirme qu’un nouvel espace anonyme vide a été créé par `AccountModel` ;
9. affirme que la clé témoin est intacte.

Le test doit échouer sur l’implémentation actuelle parce que
`via.account-data.v1.user-b` subsiste. Ne changez pas les deux tests
`testEraseDeviceData...` existants.

**Vérifier** : lancer uniquement le nouveau test avec `-only-testing` → il
échoue sur l’assertion de la clé `user-b`, et pour aucune autre raison.

### 2. Borner l’effacement au namespace des comptes Via

Dans `AccountLocalStore.eraseAll()`, sous le `locked` existant :

- obtenir les clés visibles par cette instance avec
  `defaults.dictionaryRepresentation().keys` ;
- filtrer celles qui commencent exactement par `Self.accountPrefix` ;
- appeler `removeObject(forKey:)` pour chacune ;
- supprimer séparément `legacyRecentsKey`, qui n’appartient pas au préfixe ;
- remettre `cachedSnapshot` et `activeScope` à `nil` comme aujourd’hui.

Ne pas utiliser `removePersistentDomain`, `resetStandardUserDefaults` ou un
préfixe plus court comme `via.`. L’énumération se produit uniquement lors d’une
action destructive explicite ; ne pas introduire de registre persistant de
scopes dans ce plan.

**Vérifier** : lancer `AccountModelTests` → les deux tests existants et le
nouveau test passent. Vérifier aussi avec :

```bash
rg -n 'dictionaryRepresentation|hasPrefix\(Self\.accountPrefix\)' \
  apps/via/via/Features/Account/Data/AccountLocalStore.swift
```

Résultat attendu : l’énumération bornée apparaît uniquement dans `eraseAll()`.

### 3. Vérifier la frontière entre effacement et déconnexion

Ajouter ou étendre un test de `AccountModelTests` pour confirmer qu’une
activation/désactivation normale n’efface pas un ancien workspace :

- écrire une donnée dans `user-a` ;
- passer par `activateAnonymous()` puis revenir à `user-a` ;
- vérifier que la donnée réapparaît ;
- appeler ensuite `eraseDeviceData()` et vérifier qu’elle ne réapparaît plus.

Ce test protège la distinction intentionnelle documentée par
`AccountLocalStore.swift:3-5` : la déconnexion préserve, l’effacement de
l’appareil supprime.

**Vérifier** : la commande ciblée `AccountModelTests` → exit 0.

### 4. Exécuter la non-régression iOS

**Vérifier** : après que le plan 002 a rendu `bun run test:ios` disponible,
exécuter :

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

- `AccountModelTests.testEraseDeviceDataClearsEveryPersistedAccountWorkspace` :
  deux utilisateurs, l’utilisateur oublié étant inactif au moment de l’action.
- Vérifier explicitement les clés `user-a`, `user-b` et l’ancien espace anonyme.
- Vérifier qu’`AccountModel` recrée un espace anonyme vide après la purge.
- Vérifier qu’une clé hors `via.account-data.v1.` survit.
- Conserver et exécuter les tests existants de workspace actif et d’ancien
  espace anonyme.
- Caractériser séparément qu’une simple déconnexion/changement de scope ne
  détruit pas les données.

## Critères de fin

- [ ] Tous les blobs dont la clé commence par `via.account-data.v1.` sont supprimés par `AccountLocalStore.eraseAll()`.
- [ ] Un workspace utilisateur inactif ne survit plus à `AccountModel.eraseDeviceData()`.
- [ ] Le legacy `via.recent-searches.v1` est toujours supprimé.
- [ ] Une clé `UserDefaults` étrangère au namespace des comptes reste intacte.
- [ ] Après l’action, le modèle est anonyme et son nouveau snapshot est vide.
- [ ] Une déconnexion ou un changement de scope normal continue de préserver les workspaces.
- [ ] `AccountModelTests`, la suite iOS complète et le build passent.
- [ ] Aucun fichier hors périmètre n’est modifié, hors statut de l’index.

## Conditions STOP

Arrêter et remonter le problème si :

- `accountPrefix` n’est plus le propriétaire exclusif de toutes les clés
  `AccountLocalSnapshot` ;
- une donnée de compte est persistée ailleurs que sous ce préfixe et devrait
  être incluse dans la promesse utilisateur : le périmètre doit alors être
  redéfini avec son propriétaire au lieu d’élargir aveuglément la suppression ;
- le correctif exige `removePersistentDomain` ou l’effacement complet de
  `UserDefaults` ;
- le nouveau test ne reproduit pas la conservation de `user-b` avant le fix ;
- un test de synchronisation ou de fusion échoue après le changement ;
- un changement demande de toucher un fichier hors périmètre ;
- une vérification échoue deux fois après une correction raisonnable.

## Notes de maintenance

- Toute future version du namespace de compte doit soit réutiliser une liste
  centrale de préfixes destructibles, soit migrer puis supprimer l’ancien
  namespace. Un reviewer doit rechercher les nouveaux `via.account-data.*`.
- Garder l’énumération dans l’action destructive, pas dans les chemins de
  lecture fréquents.
- En review, scrutiniser surtout la largeur du préfixe et le test de la clé
  témoin : une purge trop large serait plus grave que le bug actuel.
- Les profils et recherches ont leurs propres stores et restent coordonnés par
  `AccountDataSettingsView`; leur consolidation éventuelle est différée.
