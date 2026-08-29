# Plan 002 : Restaurer une baseline iOS complète et la rendre bloquante

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « Conditions STOP » se produit, arrêter et remonter le problème
> sans improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/via/viaTests/NetworkRemoteModelsTests.swift package.json scripts/test-ios.sh scripts/deploy-testflight.sh`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : M (environ une journée, exécution complète de la suite comprise)
- **Risque** : LOW — correction d’attentes obsolètes et ajout d’un gate, sans changement du produit
- **Dépend de** : aucun autre plan
- **Catégorie** : tests / dx
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

La cible `ViaTests` ne compile plus : trois assertions utilisent des propriétés
retirées du modèle de mobilité partagée. La commande racine `bun run test` ne
lance que les workspaces Turbo, et le déploiement TestFlight ne lance que cinq
suites liées à la recherche naturelle. Une régression iOS peut donc coexister
avec un contrôle serveur vert et atteindre le chemin de release.

Ce plan rétablit d’abord la compilation sans diminuer les assertions métier,
puis fournit une commande iOS reproductible. Le déploiement TestFlight doit
exécuter toute la cible `ViaTests` sur simulateur avant son gate Foundation
Models distinct, qui reste sur iPhone physique.

## État actuel

### Fichiers et responsabilités

- `apps/via/viaTests/NetworkRemoteModelsTests.swift` — test de décodage qui bloque actuellement toute la cible.
- `apps/via/via/Shared/Domain/SharedMobility.swift` — forme métier actuelle à laquelle les assertions doivent correspondre.
- `package.json` — commandes racine ; `test` ne couvre aujourd’hui que Turbo.
- `scripts/deploy-testflight.sh` — gate de release ; il exécute cinq suites IA ciblées, pas la cible iOS complète.
- `scripts/test-ios.sh` — nouveau point d’entrée portable à créer pour la suite complète.

### Extraits à reconnaître avant modification

`NetworkRemoteModelsTests.swift:134-149` compile contre des membres inexistants :

```swift
guard case .vehicle(let vehicle) = area.items[0] else {
  return XCTFail("The first item should be a vehicle")
}
XCTAssertEqual(vehicle.provider, .dott)
XCTAssertEqual(vehicle.mode, .bicycle)
XCTAssertEqual(vehicle.batteryPercent, 64)
XCTAssertEqual(vehicle.restrictionNote, "Zone de circulation restreinte selon Dott")

guard case .station(let station) = area.items[1] else {
  return XCTFail("The second item should be a station")
}
XCTAssertEqual(station.availability?.totalBikes, 7)
XCTAssertEqual(station.availability?.docks, 28)
```

`SharedMobility.swift:108-115,128-140,189-203` porte désormais le fait typé et
compose la station générique autour de `BikeStation` :

```swift
enum SharedMobilityRestriction: String, Codable, Hashable, Sendable {
    case noRide = "no-ride"

    func message(for provider: SharedMobilityProvider) -> String {
        switch self {
        case .noRide: "Zone de circulation restreinte selon \(provider.displayName)"
        }
    }
}

struct SharedMobilityVehicle: Codable, Hashable, Identifiable, Sendable {
    // ...
    let restriction: SharedMobilityRestriction?
}

struct SharedMobilityStation: Codable, Hashable, Identifiable, Sendable {
    let station: BikeStation
    let provider: SharedMobilityProvider
    let operatorURL: URL?
}
```

Le payload de test utilise encore `"restrictionNote"`; le contrat courant
attend `"restriction": "no-ride"`. Corriger la fixture et vérifier à la fois le
fait typé et sa phrase dérivée, afin de ne pas remplacer une assertion utile
par un simple test de compilation.

`package.json:15-18` sépare aujourd’hui le build iOS des tests Turbo :

```json
"ios": "xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'generic/platform=iOS Simulator' build",
"deploy:testflight": "bash scripts/deploy-testflight.sh",
"typecheck": "turbo run typecheck",
"test": "turbo run test"
```

`deploy-testflight.sh:172-202` ne couvre que les suites IA sur la destination
physique :

```bash
bun run typecheck
bun run test
bun run check:openapi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "$NATURAL_EVAL_DESTINATION" \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) VIA_RELEASE_EVAL_GATE' \
  -only-testing:ViaTests/NaturalJourneyUnderstandingTests \
  -only-testing:ViaTests/NaturalJourneyCriticalCorpusTests \
  -only-testing:ViaTests/OnDeviceNaturalJourneyServiceTests \
  -only-testing:ViaTests/NaturalJourneyFallbackTests \
  -only-testing:ViaTests/NaturalJourneyIntentEvalTests \
  test
```

### Travail non validé à préserver

Au moment de la rédaction, le worktree contient déjà des changements utilisateur :

- `NetworkRemoteModelsTests.swift` ajoute deux tests de fontaines avant le test
  cassé. Ne supprimer, déplacer ou réécrire aucun de ces hunks ; modifier
  uniquement la fixture et les trois assertions obsolètes du test de mobilité
  partagée.
- `package.json` contient aussi une commande d’import de fontaines non validée.
  Ajouter `test:ios` sans réordonner ni écraser les autres scripts.

Ne jamais utiliser `git checkout`, `git restore`, `git reset` ou un formatage
global pour « nettoyer » ces fichiers.

## Commandes utiles

| But                | Commande                                                                                                                                                                                                                                                               | Résultat attendu          |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| Test ciblé actuel  | `xcodebuild -quiet -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' -only-testing:ViaTests/NetworkRemoteModelsTests test` | exit 0, test ciblé vert   |
| Suite iOS complète | `xcodebuild -quiet -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' -only-testing:ViaTests test`                          | exit 0, `TEST SUCCEEDED`  |
| Build iOS          | `xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'generic/platform=iOS Simulator' 'VIA_API_CLIENT_KEY=improve-audit-placeholder' build`                                                                                       | exit 0, `BUILD SUCCEEDED` |
| Contrôles non iOS  | `bun run typecheck && bun run test && bun run check:openapi`                                                                                                                                                                                                           | trois commandes à exit 0  |
| Syntaxe shell      | `bash -n scripts/test-ios.sh scripts/deploy-testflight.sh`                                                                                                                                                                                                             | aucune sortie, exit 0     |

L’identifiant de simulateur ci-dessus était disponible lors de l’audit. S’il ne
l’est plus, utiliser `xcodebuild -project apps/via/via.xcodeproj -scheme via
-showdestinations` et choisir explicitement un simulateur iOS 26 ; ne jamais
faire tomber silencieusement le gate sur une destination générique.

## Périmètre

### Fichiers autorisés

- `apps/via/viaTests/NetworkRemoteModelsTests.swift`
- `scripts/test-ios.sh` (nouveau)
- `package.json`
- `scripts/deploy-testflight.sh`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- Les modèles, DTO, contrats TypeScript et sources OpenAPI : le code métier
  actuel est cohérent ; ce sont les attentes de test qui ont dérivé.
- Les ajouts fontaines non validés déjà présents dans le worktree.
- Le contenu des cinq suites Foundation Models et leurs seuils FR/EN.
- L’archive, la signature, l’upload App Store Connect et les secrets de release.
- La création d’une nouvelle CI hébergée : ce plan rend le gate local et
  TestFlight bloquant ; le choix d’un runner macOS reste séparé.

## Git

- Branche recommandée : `codex/002-ios-test-baseline`.
- Commits logiques suggérés :
  - `test(ios): restore shared mobility model assertions`
  - `ci(ios): gate TestFlight on the full test suite`
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Réparer les attentes de mobilité partagée sans perdre de couverture

Dans `NetworkRemoteModelsTests.swift`, conserver la structure et les ajouts
fontaines existants. Dans la fixture du véhicule :

- remplacer `"restrictionNote": "Zone ..."` par
  `"restriction": "no-ride"` ;
- remplacer l’accès inexistant `vehicle.restrictionNote` par deux assertions :
  `vehicle.restriction == .noRide` puis
  `vehicle.restriction?.message(for: vehicle.provider)` égale la phrase française ;
- accéder à la disponibilité de la station via
  `station.station.availability`, puis conserver les attentes `7` et `28` ;
- conserver les attentes de provider, mode, batterie, URL et source Lime.

Ne changez ni le modèle pour recréer les anciennes propriétés de commodité, ni
le payload pour omettre le cas de restriction.

**Vérifier** : lancer la commande « Test ciblé actuel » du tableau → exit 0 et
tous les tests `NetworkRemoteModelsTests` passent, y compris les ajouts fontaines.

### 2. Créer une commande unique pour toute la cible XCTest

Créer `scripts/test-ios.sh`, avec `#!/usr/bin/env bash` et `set -euo pipefail`,
sur le même modèle défensif que `deploy-testflight.sh` :

1. résoudre la racine depuis `BASH_SOURCE[0]`, puis s’y placer ;
2. exiger `xcodebuild` ;
3. exiger une variable non vide `IOS_TEST_DESTINATION` et afficher un message
   utile, sans valeur secrète, avant de sortir avec un code non nul si elle manque ;
4. refuser une destination générique ; elle ne peut pas exécuter XCTest ;
5. exécuter `xcodebuild` en Debug sur le projet et le scheme existants, avec
   `-only-testing:ViaTests test` ;
6. si `VIA_API_CLIENT_KEY` est présent dans l’environnement, le transmettre
   comme build setting via un tableau shell correctement quoté ; ne jamais
   l’afficher et ne jamais fournir de valeur par défaut dans le script.

Ajouter dans `package.json`, sans modifier `test`, la commande :

```json
"test:ios": "bash scripts/test-ios.sh"
```

Garder `bun run test` portable sur les runners Linux ; la composition complète
est assumée par le gate TestFlight à l’étape suivante.

**Vérifier** :

```bash
bash -n scripts/test-ios.sh
IOS_TEST_DESTINATION='platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' \
  VIA_API_CLIENT_KEY=improve-audit-placeholder \
  bun run test:ios
```

Résultat attendu : syntaxe valide, puis toute la cible `ViaTests` passe. Les
tests Foundation Models peuvent être marqués skipped sur simulateur ; aucun
test compilable ne doit être filtré individuellement.

### 3. Rendre la suite complète bloquante avant tout upload TestFlight

Dans `deploy-testflight.sh` :

- documenter `ASC_IOS_TEST_DESTINATION` dans la section d’aide ;
- lire sa valeur dans `IOS_TEST_DESTINATION` à côté de
  `NATURAL_EVAL_DESTINATION` ;
- après le retour anticipé `--dry-run`, exiger les deux destinations ;
- refuser pour `IOS_TEST_DESTINATION` une valeur qui ne cible pas un simulateur
  iOS, et continuer de refuser un simulateur pour `NATURAL_EVAL_DESTINATION` ;
- après `typecheck`, `test` et `check:openapi`, lancer :

```bash
IOS_TEST_DESTINATION="$IOS_TEST_DESTINATION" bun run test:ios
```

- conserver ensuite, sans en retirer une suite ni une condition de compilation,
  le gate Foundation Models physique actuel.

Le test iOS complet doit terminer avant le corpus live et avant la création du
dossier d’archive. Une panne XCTest doit donc arrêter le script grâce à
`set -euo pipefail`.

**Vérifier** : `bash -n scripts/test-ios.sh scripts/deploy-testflight.sh` → exit 0,
puis `rg -n 'bun run test:ios|ASC_IOS_TEST_DESTINATION' scripts/deploy-testflight.sh`
→ une déclaration, une validation et un appel bloquant sont visibles.

### 4. Exécuter la baseline complète et les contrôles transverses

**Vérifier** : exécuter successivement :

```bash
IOS_TEST_DESTINATION='platform=iOS Simulator,id=08B1F16B-17C5-4244-B657-330E9B8C23AE' \
  VIA_API_CLIENT_KEY=improve-audit-placeholder \
  bun run test:ios
bun run typecheck
bun run test
bun run check:openapi
xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  'VIA_API_CLIENT_KEY=improve-audit-placeholder' build
```

Résultat attendu : tous les exits valent 0. Les skips explicitement conçus pour
du matériel ou des services live sont acceptés ; aucune erreur de compilation,
aucun échec XCTest et aucune dérive OpenAPI ne l’est.

Enfin, examiner uniquement le diff autorisé :

```bash
git diff -- apps/via/viaTests/NetworkRemoteModelsTests.swift package.json scripts/test-ios.sh scripts/deploy-testflight.sh
```

Les hunks fontaines préexistants doivent toujours être présents et inchangés.

## Plan de test

- **Caractérisation réparée** dans `NetworkRemoteModelsTests.swift` :
  - restriction `no-ride` décodée en `.noRide` ;
  - phrase produite à partir du provider ;
  - disponibilité Vélib atteinte via la station composée ;
  - champs optionnels et sources déjà testés toujours verts.
- **Contrat du script** : absence de destination → exit non nul ; destination
  générique → exit non nul ; destination iOS 26 explicite → toute la cible est
  lancée ; la clé client n’est jamais imprimée.
- **Gate de release** : la suite complète précède le gate IA physique et
  l’archive ; `--dry-run` reste non destructif et ne demande pas de simulateur.
- **Non-régression complète** : toute la cible `ViaTests`, puis les commandes
  racine TypeScript/OpenAPI et le build iOS.

## Critères de fin

- [ ] `NetworkRemoteModelsTests` compile et passe sans recréer les anciennes propriétés métier.
- [ ] La fixture utilise `restriction: "no-ride"` et teste le fait typé ainsi que sa présentation.
- [ ] Les assertions de station passent par `station.station.availability`.
- [ ] Les changements fontaines préexistants sont intacts.
- [ ] `bun run test:ios` existe, exige une destination exécutable et lance toute la cible `ViaTests`.
- [ ] Le script TestFlight exige une destination simulateur distincte de la destination Foundation Models physique.
- [ ] La suite iOS complète est bloquante avant corpus live, archive et upload.
- [ ] La commande iOS complète sur le simulateur indiqué se termine avec `TEST SUCCEEDED`.
- [ ] `bun run typecheck`, `bun run test`, `bun run check:openapi` et le build iOS sortent à 0.
- [ ] Aucun fichier hors périmètre n’est modifié, hors statut de l’index.

## Conditions STOP

Arrêter et remonter le problème si :

- le modèle courant ne porte plus `SharedMobilityVehicle.restriction` ou
  `SharedMobilityStation.station` ;
- corriger le test exige de modifier le contrat, les sources générées ou le code métier ;
- les hunks fontaines préexistants ont disparu ou entrent en conflit avec les trois lignes ciblées ;
- une suite iOS échoue pour une raison autre que les trois attentes identifiées :
  consigner le test et l’erreur, ne pas assouplir ni filtrer la suite ;
- le simulateur `08B1F16B-17C5-4244-B657-330E9B8C23AE` n’existe plus et aucune
  autre destination iOS 26 n’est disponible ;
- le gate complet ne peut tourner qu’en supprimant le gate physique
  `VIA_RELEASE_EVAL_GATE` ; les deux ont des responsabilités distinctes ;
- le script devrait lire ou écrire un fichier de secrets pour fonctionner ;
- un changement demande de toucher un fichier hors périmètre ;
- une vérification échoue deux fois après une correction raisonnable.

## Notes de maintenance

- Toute nouvelle cible de tests iOS doit être ajoutée explicitement au script
  si elle ne fait pas partie de `ViaTests`; le nom de chaque classe, lui, ne doit
  jamais être copié dans le gate complet.
- Garder le simulateur pour la suite déterministe et l’iPhone physique pour le
  corpus Foundation Models évite de transformer un test matériel en baseline
  générale instable.
- En review, vérifier en priorité que `bun run test` n’a pas été rendu
  macOS-only, que la clé client n’apparaît dans aucun log, et que `--dry-run`
  n’exécute ni tests ni archive.
- Une future CI macOS peut appeler exactement `bun run test:ios` en fournissant
  sa destination ; elle n’a pas besoin de réinventer la commande Xcode.
