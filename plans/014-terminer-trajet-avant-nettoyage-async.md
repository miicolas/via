# Plan 014 : Terminer localement le trajet avant son nettoyage asynchrone

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « Conditions STOP » se produit, arrêter et remonter le problème
> sans improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/via/via/Features/ActiveJourney/Domain/ActiveJourneyModels.swift apps/via/via/Features/ActiveJourney/Data/ActiveJourneyStore.swift apps/via/via/Features/ActiveJourney/Presentation/ViewModel/ActiveJourneyModel.swift apps/via/via/Shared/Notifications/JourneyNotificationCoordinator.swift apps/via/via/Shared/Notifications/PushNotificationManager.swift apps/via/viaTests/ActiveJourneyModelTests.swift apps/via/viaTests/PushNotificationTests.swift`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : M (1 à 2 jours, courses déterministes comprises)
- **Risque** : HIGH — cycle de vie partagé entre état UI, persistance, GPS, Live Activity et push
- **Dépend de** : `plans/002-restaurer-baseline-tests-ios.md`
- **Catégorie** : bug
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Finir, annuler ou expirer un trajet attend d’abord ActivityKit et la
désinscription des notifications. Pendant ces suspensions, la session reste
active, le suivi GPS et les tâches continuent, et le store conserve le trajet.
Une arrivée peut donc disparaître de l’écran avant que le modèle ait réellement
terminé, et un nettoyage ancien peut interférer avec un trajet de remplacement.

Chaque chemin terminal doit d’abord effectuer une transition locale synchrone :
capturer l’ancienne activation, arrêter les tasks et le GPS, retirer la session
de l’UI, puis supprimer **cette activation seulement** du store. ActivityKit et
les notifications nettoient ensuite leur ancien identifiant sans jamais muter
le nouveau trajet.

## État actuel

### Fichiers et responsabilités

- `apps/via/via/Features/ActiveJourney/Domain/ActiveJourneyModels.swift` — payload persistant d’une session active.
- `apps/via/via/Features/ActiveJourney/Data/ActiveJourneyStore.swift` — store UserDefaults et mémoire, suppression actuellement globale.
- `apps/via/via/Features/ActiveJourney/Presentation/ViewModel/ActiveJourneyModel.swift` — trois transitions terminales et tâches de suivi.
- `apps/via/via/Shared/Notifications/JourneyNotificationCoordinator.swift` — protocole intermédiaire entre trajet actif, rappels et push.
- `apps/via/via/Shared/Notifications/PushNotificationManager.swift` — état désiré du trajet push.
- `apps/via/viaTests/ActiveJourneyModelTests.swift` — tests du modèle et fakes async.
- `apps/via/viaTests/PushNotificationTests.swift` — tests de l’outbox et du manager push.

### Extraits à reconnaître avant modification

`ActiveJourneyModel.swift:310-342` publie l’arrivée mais garde la session active
pendant deux awaits :

```swift
func finishJourney() async {
    guard let session else { return }
    let finishedAt = now()
    referenceDate = finishedAt
    arrival = JourneyArrival(/* ... */)
    await activityManager.end(/* ... */)
    await journeyNotificationManager.unregisterActiveJourney(session.journey)
    await clearSession()
}

func cancelJourney() async {
    guard let session else { return }
    let stoppedAt = now()
    await activityManager.end(/* ... */)
    await journeyNotificationManager.unregisterActiveJourney(session.journey)
    arrival = nil
    await clearSession()
}
```

L’expiration reproduit cet ordre à `ActiveJourneyModel.swift:701-725` :

```swift
private func expireJourney() async {
    guard let session else { return }
    let expiredAt = now()
    await activityManager.end(/* ... */)
    await journeyNotificationManager.unregisterActiveJourney(session.journey)
    arrival = nil
    await clearSession()
}

private func clearSession() async {
    stopTasks()
    locationModel.stopJourneyTracking()
    session = nil
    alternative = nil
    requiresResume = false
    recalculationState = .idle
    lastAutomaticRecalculationSectionID = nil
    await store.clear()
}
```

`ActiveJourneyStore.swift:3-7,28-33` n’a aucune identité de suppression :

```swift
protocol ActiveJourneyStore: Sendable {
    func load() async throws -> ActiveJourneySession?
    func save(_ session: ActiveJourneySession) async throws
    func clear() async
}

func clear() {
    defaults.removeObject(forKey: key)
}
```

`ActiveJourneySession` est identifié par `journey.id` à
`ActiveJourneyModels.swift:3-18`. Deux activations successives du même itinéraire
peuvent donc partager le même `JourneyID`; une identité de cycle de vie distincte
est nécessaire pour une suppression compare-and-clear sûre.

`JourneyNotificationCoordinator.swift:43-52` ne propage aujourd’hui que la
journey, alors que l’identité d’activation doit atteindre le propriétaire push :

```swift
protocol JourneyNotificationActiveJourneyManaging: AnyObject {
    func registerActiveJourney(_ journey: Journey) async
    func unregisterActiveJourney(_ journey: Journey) async
}
```

Enfin, `PushNotificationManager.swift:269-276` efface le désir courant sans
vérifier l’activation :

```swift
func unregisterActiveJourney(_ journey: Journey) async {
    await loadPendingRemovals()
    desiredActiveJourney = nil
    pendingActiveJourneyRegistration = nil
    guard isAuthenticated else { return }
    pendingRemovals.journeyIDs.insert(journey.id.rawValue)
    await persistPendingRemovals()
    await flush()
}
```

### Contraintes à préserver

- `arrival` doit survivre à `session` pour afficher la surface d’arrivée.
- Le haptic de fin appartient à `MapShellView`, qui survit au panel ; ne pas en
  ajouter dans le modèle.
- Les échecs ActivityKit et push restent additifs : ils ne doivent jamais
  ressusciter une session locale.
- Les anciens payloads `ActiveJourneySession` doivent rester décodables.

## Commandes utiles

| But            | Commande                                                                                                                                                                                                                                                              | Résultat attendu         |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| Tests trajet   | `xcodebuild -quiet -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' -only-testing:ViaTests/ActiveJourneyModelTests test` | exit 0                   |
| Tests push     | `xcodebuild -quiet -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' -only-testing:ViaTests/PushNotificationTests test`   | exit 0                   |
| Suite complète | `IOS_TEST_DESTINATION='platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' VIA_API_CLIENT_KEY=improve-audit-placeholder bun run test:ios`                                                                                                                 | exit 0 après le plan 002 |
| Build          | `xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'generic/platform=iOS Simulator' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' build`                                                                                      | `BUILD SUCCEEDED`        |

## Périmètre

### Fichiers autorisés

- `apps/via/via/Features/ActiveJourney/Domain/ActiveJourneyModels.swift`
- `apps/via/via/Features/ActiveJourney/Data/ActiveJourneyStore.swift`
- `apps/via/via/Features/ActiveJourney/Presentation/ViewModel/ActiveJourneyModel.swift`
- `apps/via/via/Shared/Notifications/JourneyNotificationCoordinator.swift`
- `apps/via/via/Shared/Notifications/PushNotificationManager.swift`
- `apps/via/viaTests/ActiveJourneyModelTests.swift`
- `apps/via/viaTests/PushNotificationTests.swift`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- Les vues d’arrivée, la temporisation de trois secondes et les haptics.
- Le calcul d’arrivée, la fraîcheur GPS et le recalcul d’alternative.
- Le contrat serveur d’inscription push et le format persistant de l’outbox de
  suppression. L’identité d’activation reste locale et ne devient pas un champ API.
- Le schéma de `Journey` ou son identifiant métier.
- Une suppression des Live Activities d’autres trajets ou d’autres apps.
- Le remplacement volontaire d’itinéraire dans `accept(_:)`, sauf adaptation
  mécanique à l’identité d’activation.

## Git

- Branche recommandée : `codex/014-local-first-journey-termination`.
- Commit suggéré : `fix(ios): commit journey termination before cleanup`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Écrire un test qui suspend le premier nettoyage externe

Dans `ActiveJourneyModelTests.swift`, ajouter un
`SuspendedJourneyActivityManager` actor : son `end` signale qu’il a été atteint,
puis attend une continuation contrôlée par le test ; `start` et `update` restent
non bloquants.

Ajouter aussi au fake store un mode qui suspend
`clear(ifActivationID:)` avant sa comparaison. Un test dédié lance
`finishJourney()`, attend cette suspension et affirme déjà `model.session == nil`,
`model.isTracking == false` et `model.arrival != nil`, alors que le store contient
encore A. Il reprend ensuite le store et vérifie que seule A est supprimée. Ce
test fixe précisément l’invariant « transition UI synchrone avant le premier
`await` de persistance » ; ne pas le remplacer par une attente temporelle.

Ajouter trois tests, un par chemin terminal :

- `finishJourney` : dès que `end` est atteint mais avant sa reprise,
  `model.session == nil`, `model.isTracking == false`, le store est vide et
  `arrival` est présente ;
- `cancelJourney` : aux mêmes coordonnées temporelles, session/store vides et
  aucune arrivée ;
- expiration déclenchée par `sceneBecameActive()` : session/store vides avant
  la reprise de `end`.

Ils doivent échouer sur l’implémentation actuelle parce que `session` et le
store sont encore remplis lorsque `activityManager.end` suspend.

**Vérifier** : lancer uniquement ces trois tests → échecs de caractérisation
attendus avant le fix, sans timeout de continuation.

### 2. Donner une identité persistante à chaque activation

Dans `ActiveJourneySession`, ajouter une propriété locale
`activationID: UUID` :

- valeur créée une fois par l’initialiseur, avec un paramètre par défaut
  `UUID()` pour préserver les call sites ;
- valeur encodée dans le payload ;
- décodage via `decodeIfPresent`, avec un nouveau UUID pour un payload legacy ;
- ne pas remplacer `var id: JourneyID { journey.id }`, utilisé par le domaine
  et les vues ; `activationID` sert uniquement au cycle de vie/persistance.

Étendre `testOldSessionPayloadRestoresACompatiblePlanningPolicy` : retirer aussi
`activationID` du JSON legacy, décoder, réencoder et vérifier que l’identité
générée reste stable après ce cycle.

**Vérifier** : tests ciblés d’`ActiveJourneyModelTests` → le payload legacy et
les sessions courantes passent.

### 3. Ajouter une suppression compare-and-clear au store

Étendre `ActiveJourneyStore` avec :

```swift
@discardableResult
func clear(ifActivationID activationID: UUID) async -> Bool
```

Dans les deux actors :

- charger/lire la session courante dans l’isolation de l’actor ;
- ne supprimer que si son `activationID` correspond ;
- retourner `true` uniquement lorsqu’une session correspondante a été retirée ;
- conserver `clear()` pour la récupération d’un payload illisible, où aucune
  identité ne peut être extraite.

À l’endroit où `restore()` reconnaît un payload décodable mais expiré, utiliser
la variante conditionnelle. Dans le `catch` de décodage, conserver la suppression
inconditionnelle.

Ajouter un test direct : sauvegarder A, sauvegarder B avec le **même**
`JourneyID` mais un autre `activationID`, demander la suppression de A et
vérifier que B reste chargé.

**Vérifier** : test compare-and-clear ciblé → exit 0.

### 4. Détacher la session avant le premier `await`

Dans `ActiveJourneyModel`, extraire une fonction privée **synchrone** qui reçoit
la session capturée et l’arrivée finale optionnelle, puis :

1. annule `locationTask`, `monitoringTask` et `recalculationTask` via
   `stopTasks()` ;
2. appelle `locationModel.stopJourneyTracking()` ;
3. met `session` à `nil` ;
4. vide `alternative`, `requiresResume`, `recalculationState` et
   `lastAutomaticRecalculationSectionID` ;
5. fixe `arrival` à la valeur décidée par le chemin terminal.

Pour chaque chemin :

- capturer d’abord la session, la date et le `ContentState` final qui dépend
  encore de la session ;
- construire l’arrivée pour `finishJourney`, `nil` pour cancel/expire ;
- appeler la transition synchrone ;
- `await store.clear(ifActivationID: captured.activationID)` ;
- seulement ensuite attendre `activityManager.end` et
  `journeyNotificationManager.unregisterActiveJourney` avec la journey **et
  l’`activationID`** capturés ;
- ne plus muter le modèle après ces nettoyages externes.

Une erreur ou une lenteur externe ne doit pas repousser l’état local. Ne lancez
pas un `Task.detached`; conserver l’ordre structuré et testable.

**Vérifier** : les trois tests suspendus de l’étape 1 passent et observent la
transition avant la reprise d’ActivityKit.

### 5. Propager l’identité d’activation jusqu’au propriétaire push

Changer `JourneyNotificationActiveJourneyManaging` pour exiger l’identité à
chaque appel :

```swift
func registerActiveJourney(_ journey: Journey, activationID: UUID) async
func unregisterActiveJourney(_ journey: Journey, activationID: UUID) async
```

Adapter `NoOpJourneyNotificationActiveJourneyManager`,
`JourneyNotificationCoordinator` et `PushNotificationManager`. Le coordinator
continue de gérer son reminder selon `journey.id`, mais transmet toujours
`activationID` à son `activeJourneyManager`.

Dans `ActiveJourneyModel`, chaque inscription, réinscription après foreground,
révision, remplacement et désinscription doit utiliser l’`activationID` du
`ActiveJourneySession` concerné. Ne jamais générer un UUID au call site : seule
la création de session en génère un.

Dans `PushNotificationManager`, remplacer les deux états sans scope par des
valeurs portant ensemble `journey`, `activationID` et, pour le pending, le
payload serveur :

- `desiredActiveJourney` conserve la dernière activation désirée même après un
  flush réussi ;
- `pendingActiveJourneyRegistration` porte l’activation qui l’a créé ;
- `registerActiveJourney(B, activationID: b)` remplace le désir A et retire une
  suppression distante en attente pour le même `JourneyID`, car B possède
  désormais cet abonnement serveur ;
- `unregisterActiveJourney(A, activationID: a)` ne vide le désir/pending que si
  leur **activationID** vaut `a` ;
- si le désir courant est B avec le même `JourneyID` mais un autre
  `activationID`, l’unregister A est entièrement obsolète : ne pas vider B et
  surtout ne pas ajouter ce `JourneyID` à `pendingRemovals`, car le serveur ne
  sait pas distinguer A de B et supprimerait l’abonnement de B ;
- si le désir courant concerne un autre `JourneyID`, conserver B mais mettre
  l’ancien ID de A dans l’outbox ;
- si A est encore l’activation courante, vider A et mettre son ID dans l’outbox
  comme aujourd’hui.

L’`activationID` reste un jeton local de causalité ; ne pas l’ajouter au contrat
OpenAPI ni au stockage de l’outbox, qui ne peut agir que par `JourneyID`.

**Vérifier** : build iOS vert, et `rg -n
'registerActiveJourney|unregisterActiveJourney'` sur `ActiveJourneyModel.swift`,
`JourneyNotificationCoordinator.swift` et `PushNotificationManager.swift`
montre un `activationID` explicite à chaque passage.

### 6. Caractériser A/B avec exactement le même JourneyID côté push

Dans `PushNotificationTests`, faire enregistrer par
`FakePushNotificationRemote` les inscriptions et désinscriptions, puis ajouter :

1. créer une journey et deux UUID distincts `a` et `b` ; A et B réutilisent
   volontairement la **même** valeur de `journey.id` ;
2. manager non encore authentifié : enregistrer `(journey, a)`, puis
   `(journey, b)` ;
3. appeler l’unregister tardif `(journey, a)` ;
4. activer la session et l’autorisation ;
5. vérifier que le remote reçoit l’inscription de B ;
6. vérifier qu’il ne reçoit aucune désinscription pour ce JourneyID et que
   l’outbox reste vide ;
7. ajouter un second cas avec A et B de JourneyID différents : l’unregister A
   ne supprime pas le désir B mais A est bien mis en suppression distante.

Ces tests doivent échouer avec une comparaison limitée au `JourneyID`, qui ne
peut distinguer les deux activations du premier cas.

**Vérifier** : `PushNotificationTests` → exit 0, B reste inscrite et aucune
suppression serveur ne cible son JourneyID.

### 7. Prouver qu’un nettoyage ancien ne remplace pas une nouvelle activation

Ajouter un test modèle complet :

1. démarrer A avec le manager ActivityKit suspendu ;
2. lancer `finishJourney()` dans une `Task` ;
3. attendre l’entrée dans `end` et confirmer la disparition locale de A ;
4. activer B pendant que le nettoyage de A est suspendu ; B réutilise le même
   `JourneyID` mais possède un nouvel `activationID` ;
5. reprendre le cleanup de A ;
6. attendre la task de fin ;
7. vérifier que le modèle et le store contiennent B, sans arrivée de A si le
   nouveau `begin` l’a normalement remise à nil.

Le fake `JourneyNotificationActiveJourneyManaging` doit enregistrer les couples
`(journey.id, activationID)`. Vérifier que la désinscription finale de A porte
`a`, jamais `b`; la logique de préservation du désir serveur reste testée dans
`PushNotificationTests` à l’étape 6.

**Vérifier** : test de remplacement ciblé → exit 0, B reste active et persistée,
et aucune désinscription ne cible son activation.

### 8. Exécuter la non-régression complète

**Vérifier** : exécuter les deux commandes ciblées du tableau, puis :

```bash
IOS_TEST_DESTINATION='platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' \
  VIA_API_CLIENT_KEY=improve-audit-placeholder \
  bun run test:ios
xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  'VIA_API_CLIENT_KEY=improve-audit-placeholder' build
```

Résultat attendu : tous les tests et le build passent.

## Plan de test

- Finish, cancel et expiration publient leur état local avant un `end` suspendu.
- Un `clear(ifActivationID:)` suspendu observe déjà la session détachée de l’UI,
  puis ne supprime que l’activation capturée lorsqu’il reprend.
- L’arrivée survit seulement au finish ; cancel et expiration la vident.
- Tasks de temps/recalcul, stream GPS et store sont arrêtés avant le cleanup externe.
- Compare-and-clear ne supprime pas une autre activation, y compris du même trajet.
- Un payload legacy sans `activationID` migre et reste stable après réencodage.
- Une fin A suspendue suivie d’une activation B laisse B dans modèle et store.
- Une désinscription push A tardive ne supprime pas le désir B, même quand A et
  B partagent exactement le même `JourneyID`.
- Le même cas n’enqueue aucune suppression distante ambiguë pour ce `JourneyID`.
- Les tests existants d’arrivée GPS, alternative et reprise restent inchangés.

## Critères de fin

- [ ] Les trois transitions terminales détachent la session avant leur premier nettoyage externe suspendable.
- [ ] GPS, monitoring et recalcul sont arrêtés au moment de la transition locale.
- [ ] Le store ne supprime que l’`activationID` capturé ; `clear()` global reste réservé au payload illisible.
- [ ] Les anciens payloads de session restent décodables.
- [ ] Aucune continuation de cleanup ne mute `ActiveJourneyModel` après l’installation de B.
- [ ] Le protocole de notifications propage `activationID` du modèle jusqu’au manager push.
- [ ] La désinscription push d’A conserve le désir et l’inscription de B, même avec le même `JourneyID`.
- [ ] Aucun pending removal n’est créé pour A lorsqu’il supprimerait l’abonnement serveur de B au même `JourneyID`.
- [ ] Les tests trajet, push, suite complète et build passent.
- [ ] Aucun fichier hors périmètre n’est modifié, hors statut de l’index.

## Conditions STOP

Arrêter et remonter le problème si :

- une Live Activity n’est plus adressable par `JourneyID` et exige de terminer
  globalement toutes les activités ; cela violerait l’isolation recherchée ;
- la migration de `ActiveJourneySession` rend un payload historique indécodable ;
- calculer le `ContentState` final après détachement exige de lire le nouveau
  `self.session` : calculer depuis la capture, ne pas réattacher l’ancienne ;
- le fake suspendu ne peut pas prouver l’ordre sans sleeps arbitraires ; utiliser
  des continuations, pas des délais probabilistes ;
- une désinscription serveur sait distinguer les activations autrement que par
  `JourneyID` : arrêter et documenter ce contrat avant de modifier l’API ;
- propager `activationID` impose de l’envoyer au serveur ou de modifier
  l’outbox persistante ; la solution cible doit rester une garde causale locale ;
- un changement demande de toucher un fichier hors périmètre ;
- une vérification échoue deux fois après une correction raisonnable.

## Notes de maintenance

- `JourneyID` décrit l’itinéraire ; `activationID` décrit une occurrence locale
  de suivi. Ne les fusionner ni dans les stores ni dans les tests de course.
- Une suppression distante par `JourneyID` n’est sûre que si aucune activation
  plus récente de ce même ID n’est désirée. Garder cette règle près de
  `pendingRemovals` et son test A/B.
- Tout futur effet de fin (analytics, widgets, Watch) doit recevoir la capture
  terminale et ne jamais relire `self.session` après un `await`.
- En review, vérifier la position exacte du premier `await` et l’absence de
  mutation du modèle dans la seconde moitié de chaque transition.
- Les règles « une action, un haptic » restent détenues par la vue survivante ;
  ce plan ne doit ajouter aucun feedback sensoriel au modèle.
