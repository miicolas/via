# Plan 005 : Isoler chaque mutation d’authentification par génération de session

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « Conditions STOP » se produit, arrêter et remonter le problème
> sans improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/via/via/Features/Authentication/Data/AuthSessionVault.swift apps/via/via/Features/Authentication/Presentation/ViewModel/AuthSessionViewModel.swift apps/via/via/Shared/Networking/APITransport.swift apps/via/viaTests/AuthSessionViewModelTests.swift apps/via/viaTests/TransportTests.swift`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : M (2 à 3 jours, tests de courses inclus)
- **Risque** : HIGH — le vault est partagé par toute requête et chaque transition de compte
- **Dépend de** : `plans/002-restaurer-baseline-tests-ios.md`
- **Catégorie** : bug / security
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Les opérations d’authentification capturent une session, attendent le réseau,
puis écrivent ou effacent le vault sans prouver que cette session est encore la
session courante. Une revalidation A peut donc restaurer A après une
déconnexion ou une connexion B. De même, le middleware peut recevoir tardivement
un header de rotation pour A et l’appliquer au compte B présent dans le vault.

Le vault doit devenir l’arbitre atomique des mutations. Une génération identifie
l’identité installée et une révision ordonne les mises à jour de cette identité ;
toute continuation async ne peut publier son résultat que si le snapshot qu’elle
a capturé est encore courant.

## État actuel

### Fichiers et responsabilités

- `apps/via/via/Features/Authentication/Data/AuthSessionVault.swift` — protocole, Keychain actor et fake mémoire ; les mutations sont inconditionnelles.
- `apps/via/via/Features/Authentication/Presentation/ViewModel/AuthSessionViewModel.swift` — restore, sign-in, validation, sign-out, wipe et suppression de compte.
- `apps/via/via/Shared/Networking/APITransport.swift` — charge le bearer avant la requête et applique `set-auth-token` après la réponse.
- `apps/via/viaTests/AuthSessionViewModelTests.swift` — nouveau fichier de courses déterministes à créer.
- `apps/via/viaTests/TransportTests.swift` — caractérise déjà ajout du bearer, rotation et publication du 401.

### Extraits à reconnaître avant modification

`AuthSessionVault.swift:5-10` ne porte aucune précondition :

```swift
protocol AuthSessionVault: Sendable {
    func load() async throws -> StoredAuthSession?
    func save(_ session: StoredAuthSession) async throws
    func updateBearer(_ bearerToken: String) async throws
    func clear() async throws
}
```

`AuthSessionVault.swift:77-80` applique le bearer à la session trouvée **au
retour** de la requête, pas à celle qui a émis la requête :

```swift
func updateBearer(_ bearerToken: String) throws {
    guard var session = try load(), session.bearerToken != bearerToken else { return }
    session.bearerToken = bearerToken
    try save(session)
}
```

`AuthSessionViewModel.swift:163-174` relit puis efface autour de plusieurs
suspensions :

```swift
func signOut() async {
    guard let displayedSession = session else { return }
    let storedSession = (try? await vault.load()) ?? displayedSession
    await onAuthenticatedSessionEnded()
    try? await client.signOut(bearerToken: storedSession.bearerToken)
    try? await vault.clear()
    anonymousSession = nil
    account.activateAnonymous()
    state = .signedOut
    errorMessage = nil
    await establishAnonymousSession()
}
```

`AuthSessionViewModel.swift:236-253` écrit toujours la validation capturée :

```swift
let storedSession = (try? await vault.load()) ?? displayedSession
do {
    let refreshed = try await client.validate(storedSession)
    try await vault.save(refreshed)
    state = .authenticated(refreshed, .online)
    errorMessage = nil
    account.synchronize()
} catch AuthenticationClientError.unauthorized {
    await clearConfirmedSession(/* ... */)
}
```

`APITransport.swift:118-133` présente la même fenêtre :

```swift
var bearerToken: String?
if let session = try? await vault.load() {
    bearerToken = session.bearerToken
    request.headerFields[.authorization] = "Bearer \(session.bearerToken)"
}
let response = try await next(request, body, baseURL)
if let bearer = response.0.headerFields[name], !bearer.isEmpty {
    try? await vault.updateBearer(bearer)
}
```

### Modèle de concurrence cible

Définir dans `AuthSessionVault.swift` un snapshot `Sendable` contenant :

- `session: StoredAuthSession?` ;
- `generation: UInt64` — change quand une identité est installée ou retirée ;
- `revision: UInt64` — change à chaque mutation acceptée, bearer compris.

La génération protège A contre B. La révision protège deux réponses concurrentes
de A. Ces compteurs sont locaux au process et n’ont pas besoin d’être encodés
avec le bearer : aucune task d’un ancien process ne survit à un relaunch.

## Commandes utiles

| But            | Commande                                                                                                                                                                                                                                                                                                      | Résultat attendu         |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| Tests auth     | `xcodebuild -quiet -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' -only-testing:ViaTests/AuthSessionViewModelTests -only-testing:ViaTests/TransportTests test` | exit 0                   |
| Suite complète | `IOS_TEST_DESTINATION='platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' VIA_API_CLIENT_KEY=improve-audit-placeholder bun run test:ios`                                                                                                                                                         | exit 0 après le plan 002 |
| Build          | `xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'generic/platform=iOS Simulator' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' build`                                                                                                                              | `BUILD SUCCEEDED`        |

## Périmètre

### Fichiers autorisés

- `apps/via/via/Features/Authentication/Data/AuthSessionVault.swift`
- `apps/via/via/Features/Authentication/Presentation/ViewModel/AuthSessionViewModel.swift`
- `apps/via/via/Shared/Networking/APITransport.swift`
- `apps/via/viaTests/AuthSessionViewModelTests.swift` (nouveau)
- `apps/via/viaTests/TransportTests.swift`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- Le format de `StoredAuthSession` et les réponses Better Auth.
- Les endpoints, cookies, TTL serveur et le header `set-auth-token`.
- Le service Keychain, sa migration v1 → v2 et son niveau d’accessibilité.
- La suppression des workspaces `UserDefaults`, traitée par le plan 006.
- Le flux UI Sign in with Apple et ses haptics.
- La logique du `PushNotificationManager`; le callback de fin de session reste
  exécuté, mais un résultat auth ancien ne peut plus modifier une nouvelle génération.

## Git

- Branche recommandée : `codex/005-auth-session-generations`.
- Commit suggéré : `fix(ios): scope auth mutations to session generations`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Écrire les courses de régression avant de changer le vault

Créer `AuthSessionViewModelTests.swift` en `@MainActor`. Utiliser
`AccountModel(remote: InMemoryAccountRemote(), synchronizationEnabled: false)`
et un `SuspendedAuthenticationClient` actor piloté par continuations, sans
`Task.sleep` arbitraire.

Ajouter au minimum :

1. **validation A puis sign-in B** : `restore()` installe visuellement A et
   suspend `validate(A)` ; `completeSignIn` installe B ; la validation A reprend ;
   état et vault doivent rester B ;
2. **validation A puis sign-out** : validation suspendue, sign-out terminé et
   session anonyme établie, puis reprise de A ; A ne doit jamais réapparaître ;
3. **401 ancien** : après installation de B, publier le bearer rejeté de A ; B
   reste installée ;
4. **deux validations de la même génération** : une réponse arrivée après une
   mutation de bearer plus récente ne peut pas remettre l’ancienne révision.

Les fakes doivent offrir `waitUntilValidationStarted()` et des méthodes de
reprise explicites. Ne jamais placer les bearers réels ou une valeur de secret
dans les fixtures ; des sentinelles comme `a.token` et `b.token` suffisent.

**Vérifier** : les deux premiers tests reproduisent le bug ou restent
impossibles à sécuriser avec le protocole actuel ; consigner précisément
l’assertion avant d’implémenter.

### 2. Remplacer les mutations libres par un snapshot versionné

Dans `AuthSessionVault.swift`, introduire des petits types valeur, par exemple
`AuthSessionGeneration`, `AuthSessionRevision` et `AuthSessionSnapshot`, plutôt
que de passer trois scalaires non nommés.

Le protocole doit exposer des opérations atomiques dont le résultat indique si
la précondition était encore vraie :

- `snapshot()` — charge la session et ses deux versions ;
- `install(_:replacingGeneration:)` — pour une nouvelle identité/une nouvelle
  session anonyme ; compare la génération, écrit, incrémente génération et révision ;
- `refresh(_:matching:)` — compare génération **et** révision, exige le même
  `user.id` et le même statut anonyme, écrit et incrémente seulement la révision ;
- `updateBearer(_:matching:)` — compare génération et révision, modifie la
  session capturée seulement, incrémente la révision ;
- `clear(matching:)` — compare snapshot complet, pour une erreur réseau liée à
  une requête précise ;
- `clear(matchingGeneration:)` — compare l’identité mais tolère une rotation de
  bearer concurrente, pour une action explicite sign-out/wipe.

Faire retourner le nouveau snapshot après succès, `nil` après conflit. Utiliser
`&+=` pour des compteurs locaux dont le wrap conserve la sémantique pratique.
Les opérations Keychain doivent rester dans l’actor et n’avoir aucun `await`
entre comparaison et écriture.

Adapter `InMemoryAuthSessionVault` au même contrat ; c’est l’oracle des tests.
Conserver des helpers privés de lecture/écriture Keychain et la migration legacy.

**Vérifier** : ajouter des tests de vault dans `AuthSessionViewModelTests` :
install stale refusé, refresh stale refusé, bearer stale refusé, clear de la
génération courante accepté. Tous passent sur les deux comportements couverts
par le fake mémoire.

### 3. Lier la rotation HTTP au snapshot ayant émis la requête

Dans `BearerAuthenticationMiddleware.intercept` :

- capturer un `AuthSessionSnapshot` avant `next` ;
- ajouter l’Authorization depuis `snapshot.session` ;
- après la réponse, appeler `updateBearer(_:matching: snapshot)` ;
- si la mutation retourne `nil`, ignorer le header tardif sans erreur utilisateur ;
- continuer de publier au flux 401 le bearer réellement envoyé, pas le bearer
  éventuellement courant après la réponse.

Étendre `TransportTests` avec une closure `next` suspendue :

1. A émet la requête ;
2. pendant la suspension, installer B dans le vault ;
3. répondre avec `set-auth-token: a.rotated` ;
4. vérifier que le vault contient toujours B ;
5. vérifier que le 401 éventuel cite `a.token`.

Adapter le test existant pour lire `vault.snapshot().session?.bearerToken`; ses
attentes fonctionnelles restent les mêmes lorsque personne ne change la session.

**Vérifier** : `TransportTests` → tous les tests passent.

### 4. Scoper restore, validation et session anonyme

Dans `AuthSessionViewModel` :

- `restore()` commence par un snapshot et choisit l’état depuis sa session ;
- passer le snapshot aux helpers privés de revalidation au lieu de relire une
  session de fallback non versionnée ;
- après `client.validate`, appeler `refresh(_:matching:)` et ne mettre à jour
  `state`, `anonymousSession`, `errorMessage` ou `account` que si le vault
  retourne un snapshot accepté ;
- sur `.unauthorized`, utiliser `clear(matching:)` pour qu’un 401 de l’ancienne
  révision ne supprime pas une rotation ou une identité plus récente ;
- `establishAnonymousSession` capture d’abord un snapshot vide, attend le
  client, puis appelle `install(_:replacingGeneration:)`; un résultat stale est
  abandonné silencieusement ;
- remplacer le booléen global `isRevalidating` par un propriétaire identifié
  par génération, ou vérifier dans le `defer` qu’il libère encore la même
  génération. Une ancienne validation ne doit pas déverrouiller le travail de B.

Les erreurs réseau continuent de conserver une session offline **uniquement si
son snapshot est courant**. Une continuation stale ne doit même pas changer le
message d’erreur.

**Vérifier** : les tests restore/validation/anonyme ciblés passent, puis build iOS.

### 5. Scoper toutes les transitions explicites d’identité

Adapter chaque chemin public :

- `completeSignIn(.authorized)` capture le snapshot anonyme avant l’appel Apple
  serveur, puis installe le résultat en remplaçant cette génération ;
- `signOut()` capture la génération de la session affichée. Après les nettoyages
  associés à cette session, il efface seulement cette génération ; il ne passe
  à `.signedOut`, n’active l’anonyme et n’établit une session anonyme que si le
  clear a été accepté ;
- `eraseDeviceData()` applique la même règle avant `account.eraseDeviceData()` ;
  une vieille action ne doit pas effacer le workspace d’une nouvelle session ;
- `completeAccountDeletion` capture la génération avant l’appel distant et ne
  termine localement que si elle est encore courante au retour ;
- `authenticatedRequestWasRejected` compare snapshot et bearer envoyé, puis
  appelle le clear exact ;
- `appleCredentialWasRevoked` et `clearConfirmedSession` utilisent le snapshot
  authentifié courant et abandonnent tout résultat conflictuel.

Après chaque `await` externe, utiliser le résultat CAS du vault comme preuve ;
ne pas se contenter de comparer `state`, qui est une projection UI. Garder la
session concernée non disponible à une seconde action utilisateur pendant son
nettoyage avec l’état de transition existant, sans ajouter un nouveau bouton.

**Vérifier** : `AuthSessionViewModelTests` → les quatre courses de l’étape 1
passent et aucune session A ne réapparaît après B.

### 6. Vérifier tous les call sites et la non-régression complète

**Vérifier** : rechercher les anciennes opérations :

```bash
rg -n 'vault\.(load|save|updateBearer|clear)\(' \
  apps/via/via/Features/Authentication \
  apps/via/via/Shared/Networking \
  apps/via/viaTests
```

Résultat attendu : aucun call site non versionné ; les noms nouveaux contiennent
un snapshot ou une génération explicite. Puis exécuter :

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

- Validation A suspendue, installation B, réponse A tardive : B reste partout.
- Validation A suspendue, sign-out puis anonyme, réponse A : A ne revient pas.
- Rotation bearer A tardive après B : le token de B est intact.
- 401 émis avec A après B : B n’est pas effacée.
- Deux réponses de même génération : seule la révision encore courante écrit.
- Sign-out tolère une rotation bearer de sa propre génération mais refuse de
  supprimer une génération B.
- Erreur transport d’une validation stale ne change ni connectivité ni message.
- Migration Keychain v1, session offline et établissement anonyme existants
  restent fonctionnels via la suite complète.

## Critères de fin

- [ ] Le vault fournit un snapshot génération + révision et arbitre atomiquement chaque mutation.
- [ ] Une identité installée change la génération ; une rotation conserve la génération et change la révision.
- [ ] Aucun `save`, `updateBearer` ou `clear` inconditionnel n’est accessible aux call sites auth/transport.
- [ ] Toute continuation du view model abandonne ses mutations UI si son CAS échoue.
- [ ] Le middleware ne peut pas appliquer un bearer reçu pour A à la session B.
- [ ] Un 401 ancien ne peut pas déconnecter une session plus récente.
- [ ] Les tests de courses, `TransportTests`, la suite iOS complète et le build passent.
- [ ] Aucun fichier hors périmètre n’est modifié, hors statut de l’index.

## Conditions STOP

Arrêter et remonter le problème si :

- Better Auth exige qu’un header de rotation tardif soit appliqué à une autre
  identité que celle ayant émis la requête ; cela contredirait l’isolation du bearer ;
- une opération atomique Keychain nécessite un `await` entre comparaison et
  écriture ; garder la décision dans l’actor ou redéfinir le plan ;
- le callback `onAuthenticatedSessionEnded` peut déclencher lui-même une nouvelle
  connexion réentrante en production : il faudra lui donner un scope de
  génération explicite au lieu de supposer une transition séquentielle ;
- le test de course nécessite des sleeps pour reproduire le bug ; utiliser des
  continuations et signaux déterministes ;
- la migration Keychain existante cesse de préserver une session valide ;
- le correctif exige de persister un bearer ou un secret supplémentaire ;
- un changement demande de toucher un fichier hors périmètre ;
- une vérification échoue deux fois après une correction raisonnable.

## Notes de maintenance

- La génération représente l’identité installée, la révision représente son
  contenu mutable. Toute nouvelle mutation du vault doit déclarer laquelle des
  deux elle change.
- Les compteurs restent en mémoire : la persistance Keychain contient la vérité
  d’un nouveau process, qui démarre sans task concurrente de l’ancien.
- En review, suivre chaque capture de snapshot jusqu’à son CAS et vérifier
  qu’aucune mutation UI ne se trouve après un échec CAS.
- Ne jamais logger un snapshot entier : il contient un bearer. Les diagnostics
  peuvent journaliser uniquement conflit accepté/refusé et génération hachée si
  cela devient nécessaire.
