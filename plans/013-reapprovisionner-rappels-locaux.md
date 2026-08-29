# Plan 013 : Réapprovisionner les rappels locaux hors de l’écran Réglages

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « Conditions STOP » se produit, arrêter et remonter le problème
> sans improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/via/via/Features/Notifications/Data/NotificationScheduleCoordinator.swift apps/via/via/App/ApplicationLifecycle.swift apps/via/via/App/ApplicationEntry.swift apps/via/viaTests/NotificationScheduleCoordinatorTests.swift`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : M (environ 1 à 2 jours avec seam système et tests calendrier)
- **Risque** : MED — orchestration de notifications au lancement et au foreground
- **Dépend de** : `plans/002-restaurer-baseline-tests-ios.md`
- **Catégorie** : bug
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Chaque programmation de trajet installe seulement trois notifications locales
à occurrence unique. Le seul appel de réconciliation dépend actuellement de la
présence de `NotificationSettingsView`; après trois occurrences, un voyageur
qui utilise normalement la carte ne reçoit plus aucun rappel.

La programmation doit être réapprovisionnée après la restauration du compte et
à chaque passage actif de l’application. L’écran Réglages conserve son appel
pour refléter immédiatement une édition, mais il ne doit plus être le
propriétaire de la continuité du service.

## État actuel

### Fichiers et responsabilités

- `apps/via/via/Features/Notifications/Data/NotificationScheduleCoordinator.swift` — calcule et remplace les requêtes locales.
- `apps/via/via/App/ApplicationLifecycle.swift` — ordonne les restaurations indépendantes au lancement.
- `apps/via/via/App/ApplicationEntry.swift` — reçoit `scenePhase` et possède `AccountModel`.
- `apps/via/via/Shared/Notifications/JourneyNotificationCoordinator.swift` — contient le seam `JourneyNotificationCenterClient` déjà utilisé par les tests système.
- `apps/via/viaTests/NotificationScheduleCoordinatorTests.swift` — nouveau fichier de caractérisation à créer.

### Extraits à reconnaître avant modification

`NotificationScheduleCoordinator.swift:66-73,91-102` limite chaque schedule à
trois événements et le total à 60 :

```swift
/// Keeps at most three upcoming local reminders per commute schedule.
func reconcile(
    schedules: [NotificationSchedule],
    preferences: NotificationPreferences,
    now: Date? = nil
) async {
    // ...
    let reference = now ?? self.now()
    let events = schedules
        .filter { /* enabled commute schedules */ }
        .flatMap { schedule in
            upcomingEvents(for: schedule, preferences: preferences, after: reference)
        }
        .prefix(60)
```

`NotificationScheduleCoordinator.swift:141-167` matérialise cette limite :

```swift
var events: [LocalNotificationEvent] = []
for offset in 0..<42 where events.count < 3 {
    // sélection du jour, jours fériés et heures calmes
    events.append(LocalNotificationEvent(/* ... */))
}
return events
```

`NotificationSettingsView.swift:109-119` est le seul propriétaire actuel de
la réconciliation :

```swift
.task(id: scenePhase) {
    guard scenePhase == .active else { return }
    await coordinator.restore()
    await journeyNotificationCoordinator.refreshAuthorizationStatus()
}
.task(id: reconciliationKey) {
    await coordinator.reconcile(
        schedules: accountModel.notificationSchedules,
        preferences: accountModel.notificationPreferences
    )
}
```

`ApplicationEntry.swift:150-168` possède déjà les deux moments de cycle de vie
nécessaires, mais ne touche pas aux programmations locales :

```swift
.task {
    await ApplicationLifecycle.restore(/* ... */)
}
.task(id: scenePhase) {
    guard scenePhase == .active else { return }
    await authSessionViewModel.sceneBecameActive()
    await activeJourneyModel.sceneBecameActive()
    await journeyNotificationCoordinator.sceneBecameActive()
    // push authorization and flush
}
```

### Seam système à réutiliser

`JourneyNotificationCoordinator.swift:5-12` définit déjà les opérations exactes
dont le schedule coordinator a besoin :

```swift
@MainActor
protocol JourneyNotificationCenterClient: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}
```

Réutiliser ce seam au lieu d’introduire un second protocole presque identique.
Un renommage global plus générique serait cohérent mais dépasse ce correctif.

## Commandes utiles

| But            | Commande                                                                                                                                                                                                                                                                                                                                                                                 | Résultat attendu         |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| Tests ciblés   | `xcodebuild -quiet -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' -only-testing:ViaTests/NotificationScheduleCoordinatorTests -only-testing:ViaTests/NotificationAuthorizationTests -only-testing:ViaTests/JourneyNotificationTests test` | exit 0                   |
| Suite complète | `IOS_TEST_DESTINATION='platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' VIA_API_CLIENT_KEY=improve-audit-placeholder bun run test:ios`                                                                                                                                                                                                                                    | exit 0 après le plan 002 |
| Build          | `xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'generic/platform=iOS Simulator' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' build`                                                                                                                                                                                                         | `BUILD SUCCEEDED`        |

## Périmètre

### Fichiers autorisés

- `apps/via/via/Features/Notifications/Data/NotificationScheduleCoordinator.swift`
- `apps/via/via/App/ApplicationLifecycle.swift`
- `apps/via/via/App/ApplicationEntry.swift`
- `apps/via/viaTests/NotificationScheduleCoordinatorTests.swift` (nouveau)
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `NotificationSettingsView` : son `task(id: reconciliationKey)` reste utile
  pour appliquer immédiatement une édition.
- Le nombre de trois occurrences par schedule et la limite système globale de
  60 ; ce plan réapprovisionne, il ne redéfinit pas la capacité produit.
- Les notifications push, les rappels d’un trajet actif et leur outbox.
- Le calcul des jours fériés, des heures calmes, de DST et du fuseau existant.
- Les contrôles, haptics et écrans de réglages.
- Un background task iOS : le foreground est la frontière demandée.

## Git

- Branche recommandée : `codex/013-replenish-local-reminders`.
- Commit suggéré : `fix(ios): replenish commute reminders on foreground`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Rendre le coordinateur testable sans dupliquer l’adapter système

Dans `NotificationScheduleCoordinator` :

- remplacer `UNUserNotificationCenter` par
  `any JourneyNotificationCenterClient` ;
- utiliser `SystemJourneyNotificationCenter()` comme valeur par défaut ;
- remplacer `notificationSettings().authorizationStatus` par
  `center.authorizationStatus()` ;
- transmettre ce même center à
  `NotificationAuthorization.request(center:)` ;
- conserver les appels `add`, `pendingNotificationRequests` et
  `removePendingNotificationRequests` via le protocole.

Les previews et `shared` ne doivent changer ni de signature publique ni de
comportement.

**Vérifier** : lancer la commande « Build » du tableau → `BUILD SUCCEEDED`.

### 2. Caractériser le réapprovisionnement et le remplacement idempotent

Créer `NotificationScheduleCoordinatorTests.swift` en `@MainActor`. Reprendre
la structure de `FakeJourneyNotificationCenter` dans
`JourneyNotificationTests.swift:421-459`, avec :

- statut mutable ;
- tableau de requêtes où `add` remplace un identifiant identique ;
- enregistrement des identifiants supprimés ;
- possibilité de faire échouer un ajout.

Créer une `NotificationSchedule` commute déterministe (Europe/Paris, un jour
ouvré connu, rappel activé, pas de suppression) et une préférence par défaut.
Tester :

1. une première réconciliation autorisée installe exactement trois requêtes ;
2. après avoir avancé `now` au-delà des trois occurrences et rappelé
   `reconcile`, trois nouveaux identifiants futurs remplacent les anciens ;
3. deux réconciliations au même instant ne produisent aucun doublon ;
4. une autorisation refusée retire les anciennes requêtes et n’en ajoute aucune ;
5. l’échec d’un ajout expose le message actuel sans perdre la programmation de
   compte, qui n’appartient pas au center.

Inspecter les `UNCalendarNotificationTrigger.nextTriggerDate()` ou leurs
composants plutôt que comparer une description textuelle localisée.

**Vérifier** : lancer `NotificationScheduleCoordinatorTests` → tous les nouveaux
tests passent après le seam, et aucun accès au center système réel n’a lieu.

### 3. Coalescer les demandes concurrentes de réconciliation

L’ajout d’appels de cycle de vie peut chevaucher le `task` de l’écran Réglages.
Éviter deux séquences concurrentes « supprimer tout puis ajouter » :

- conserver au plus un travail de réconciliation actif ;
- si un appel arrive pendant une suspension du center, mémoriser le dernier
  triplet `schedules`, `preferences`, `reference` ;
- après la séquence active, rejouer la dernière demande mémorisée avant de
  remettre `isReconciling` à `false` ;
- ne jamais ignorer définitivement une édition plus récente avec un simple
  `guard !isReconciling else { return }` ;
- conserver `isReconciling` comme état observable de toute la boucle.

Ajouter un test dont le fake suspend le premier `add`, lance une seconde
réconciliation avec un schedule révisé, puis reprend. L’état final du fake doit
correspondre uniquement à la révision la plus récente.

**Vérifier** : test de coalescence ciblé → exit 0, trois requêtes de la dernière
révision et aucune de l’ancienne à la fin.

### 4. Réconcilier après restauration du compte

Étendre `ApplicationLifecycle.restore` avec deux dépendances explicites :

- `accountModel: AccountModel` ;
- `notificationScheduleCoordinator: NotificationScheduleCoordinator`.

Après `await auth`, lorsque `AuthSessionViewModel.restore()` a activé le bon
workspace local, appeler :

```swift
await notificationScheduleCoordinator.reconcile(
    schedules: accountModel.notificationSchedules,
    preferences: accountModel.notificationPreferences
)
```

Conserver les autres restaurations parallèles. Dans `ApplicationEntry`, passer
`accountModel` et `NotificationScheduleCoordinator.shared` au nouvel appel.

**Vérifier** : `rg -n 'notificationScheduleCoordinator.*reconcile|reconcile\('
apps/via/via/App/ApplicationLifecycle.swift` → un appel après la restauration
auth, puis build iOS vert.

### 5. Réconcilier à chaque foreground hors de l’écran Réglages

Dans le `task(id: scenePhase)` d’`ApplicationEntry`, après
`authSessionViewModel.sceneBecameActive()` — qui peut invalider ou réactiver un
workspace — appeler le singleton avec les schedules et préférences **relus à ce
moment** depuis `accountModel`.

Ne capturer les tableaux ni dans `init`, ni avant la revalidation auth. Conserver
les appels du trajet actif et du push existants.

**Vérifier** : build iOS vert, puis rechercher les propriétaires :

```bash
rg -n 'NotificationScheduleCoordinator\.shared|\.reconcile\(' \
  apps/via/via/App/ApplicationEntry.swift \
  apps/via/via/App/ApplicationLifecycle.swift \
  apps/via/via/Features/Notifications/Presentation/View/NotificationSettingsView.swift
```

Résultat attendu : lancement, foreground et édition en Réglages sont les trois
chemins explicites.

### 6. Exécuter la non-régression notifications et iOS

**Vérifier** : exécuter la commande ciblée du tableau, puis :

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

- Première installation : trois occurrences futures, identifiants Via stables.
- Foreground après consommation des trois : trois occurrences suivantes.
- Foreground répété au même instant : aucun doublon.
- Édition pendant une réconciliation suspendue : seule la dernière révision
  demeure installée.
- Autorisation refusée : anciennes requêtes Via retirées, aucune nouvelle.
- Erreur d’ajout : message existant conservé et nouvel essai possible.
- Non-régression de `NotificationAuthorizationTests` et
  `JourneyNotificationTests`, puisque le seam est partagé.

## Critères de fin

- [ ] `NotificationScheduleCoordinator` est testable via le center client existant.
- [ ] Trois rappels sont installés après la restauration du bon workspace.
- [ ] Chaque passage actif réapprovisionne les rappels sans ouvrir Réglages.
- [ ] Une édition dans Réglages continue de se refléter immédiatement.
- [ ] Deux réconciliations chevauchées convergent vers la demande la plus récente.
- [ ] Les limites de trois par schedule et 60 au total restent inchangées.
- [ ] Les tests ciblés, la suite iOS complète et le build passent.
- [ ] Aucun fichier hors périmètre n’est modifié, hors statut de l’index.

## Conditions STOP

Arrêter et remonter le problème si :

- `AuthSessionViewModel.restore()` ne garantit plus l’activation du workspace
  local avant son retour ; les schedules ne doivent pas être lus dans le mauvais scope ;
- réutiliser `JourneyNotificationCenterClient` exige de changer son contrat ou
  le comportement des rappels de trajet actif ;
- le calcul existant produit moins de trois occurrences pour la fixture à cause
  d’un jour férié ou d’heures calmes : corriger la fixture, pas la logique métier ;
- la coalescence perd la dernière édition ou laisse `isReconciling` bloqué ;
- le changement exige un background mode ou une nouvelle autorisation iOS ;
- un changement demande de toucher un fichier hors périmètre ;
- une vérification échoue deux fois après une correction raisonnable.

## Notes de maintenance

- Les programmations locales restent des one-shots afin de respecter jours
  fériés et heures calmes ; cela rend le foreground propriétaire du remplissage.
- Toute nouvelle mutation de `notificationSchedules` hors Réglages doit appeler
  la même réconciliation ou déclencher le mécanisme central.
- En review, vérifier l’ordre auth → lecture du compte → reconcile, ainsi que la
  convergence du test concurrent.
- Le nom `JourneyNotificationCenterClient` est désormais utilisé par deux
  familles de notifications. Un renommage en `NotificationCenterClient` peut
  être fait plus tard comme refactor mécanique séparé.
