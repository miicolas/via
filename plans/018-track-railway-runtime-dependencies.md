# Plan 018: Déclencher Railway sur toute dépendance qui change le service construit

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- .railway/railway.ts railway.marketing.json railway.disruptions.json railway.gtfs.json railway.toilets.json railway.fountains.json apps/worker/railway.elevators.json scripts/package.json scripts/railway-watch-patterns.test.ts`
> Au moment de la rédaction, `.railway/railway.ts` et `railway.fountains.json`
> contenaient déjà un nouveau service fountains, et `apps/worker/package.json`
> son script `import-fountains`. Conserver intégralement ces ajouts. Si le diff
> contient un autre remaniement Railway, le réconcilier avant de continuer.

## Statut

- **Priorité** : P2
- **Effort** : S (patterns, test de configuration et validation TypeScript/JSON)
- **Risque** : LOW — davantage de builds peuvent être déclenchés, sans changement du code exécuté
- **Dépend de** : aucun autre plan
- **Catégorie** : dx / bug
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Railway n’amorce un nouveau déploiement que lorsqu’un chemin correspondant à
`watchPatterns` change. Le build marketing importe `@via/contract`, mais ses
patterns surveillent seulement `apps/marketing` et les fichiers racine : une
évolution du schéma partagé peut donc déployer l’API sans reconstruire le site
qui le consomme. D’autres fichiers Railway ont déjà divergé entre JSON et IaC,
notamment les crons worker et le job disruptions. Ce plan aligne chaque service
sur la fermeture de ses dépendances runtime/build et ajoute un test qui rend la
prochaine omission visible dans `bun run test`.

## État actuel

### Fichiers et responsabilités

- `railway.marketing.json` — configuration réellement référencée par le service marketing.
- `.railway/railway.ts` — IaC qui répète le build et les watch patterns du marketing et factorise ceux des crons worker.
- `railway.json` — API principale ; surveille déjà `/apps/api/**` et `/packages/**`.
- `railway.disruptions.json` — job basé dans `apps/api`, mais ne surveille que deux sous-arbres alors que ses imports traversent `env`, `http`, `redis`, `time` et `idfm`.
- `railway.gtfs.json`, `railway.toilets.json`, `railway.fountains.json`, `apps/worker/railway.elevators.json` — variantes JSON du même package worker.
- `scripts/package.json` — package de scripts actuellement typechecké mais sans tâche test.

### Preuve de la dépendance oubliée

`apps/marketing/package.json:16-19` :

```json
"dependencies": {
  "@tanstack/react-query": "^5.102.5",
  "@via/contract": "workspace:*"
}
```

Le runtime l’importe réellement dans :

```ts
// apps/marketing/src/lib/journey-share.ts:1-4
import {
  journeyShareResponseSchema,
  type JourneyShareResponse,
} from "@via/contract";

// apps/marketing/src/lib/lines.ts
import {} from /* projections publiques */ "@via/contract/public";
```

`railway.marketing.json:5-12` ne couvre pourtant pas ce package :

```json
"buildCommand": "bun run --filter=@via/marketing build",
"watchPatterns": [
  "/apps/marketing/**",
  "/package.json",
  "/bun.lock",
  "/turbo.json",
  "/patches/**",
  "/railway.marketing.json"
]
```

La même omission est copiée dans `.railway/railway.ts:96-107`.

### Divergences voisines à fermer dans le même invariant

- `.railway/railway.ts:119-137` explique que tous les crons worker doivent
  partager `/apps/worker/**`, `/packages/contract/**` et `/packages/db/**`.
- `apps/worker/railway.elevators.json:6-12` respecte déjà cette liste.
- `railway.gtfs.json`, `railway.toilets.json` et le nouveau
  `railway.fountains.json` omettent encore `/packages/contract/**`.
- `railway.disruptions.json:6-14` surveille quelques chemins de l’API, alors que
  `apps/api/src/jobs/disruptions-history/run.ts` importe `../../redis` et
  `routers/lines/disruptions/snapshot.ts` importe `env`, `redis` et le budget
  IDFM hors des deux sous-arbres surveillés. Son build typechecke en outre tout
  `@via/api`.

### Contraintes à conserver

- Les patterns Railway sont ancrés à la racine avec `/` et utilisent `/**` pour
  les arbres. Suivre la
  [documentation officielle des watch paths](https://docs.railway.com/builds/build-configuration).
- Un fichier de configuration doit se surveiller lui-même pour qu’un changement
  de build/déploiement déclenche une reconstruction.
- Préférer une dépendance directe précise (`/packages/contract/**`) quand elle
  est stable. Pour `@via/api`, dont le build et le job traversent beaucoup de
  sous-arbres, `/apps/api/**` et `/packages/**` sont plus sûrs qu’une liste
  manuelle fragile.
- Ne pas modifier schedules, commandes de démarrage, régions, volumes,
  variables ou secrets.
- Les ajouts fountains présents dans le worktree appartiennent à l’utilisateur ;
  ce plan ajuste uniquement leur tableau de watch patterns si nécessaire.

## Commandes utiles

| But                | Commande                                                                                                                                                                                                                           | Résultat attendu                                |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| Test ciblé         | `bun test scripts/railway-watch-patterns.test.ts`                                                                                                                                                                                  | tous les invariants passent                     |
| Tests monorepo     | `bun run test`                                                                                                                                                                                                                     | tous les packages, dont `@via/scripts`, passent |
| Typecheck monorepo | `bun run typecheck`                                                                                                                                                                                                                | exit 0                                          |
| Typecheck IaC      | `bunx tsc --ignoreConfig --noEmit --skipLibCheck --module Preserve --moduleResolution bundler --target ESNext .railway/railway.ts`                                                                                                 | exit 0                                          |
| JSON valides       | `bun -e 'for (const f of ["railway.json","railway.marketing.json","railway.disruptions.json","railway.gtfs.json","railway.toilets.json","railway.fountains.json","apps/worker/railway.elevators.json"]) await Bun.file(f).json()'` | exit 0                                          |

## Périmètre

### Fichiers autorisés

- `railway.marketing.json`
- `railway.disruptions.json`
- `railway.gtfs.json`
- `railway.toilets.json`
- `railway.fountains.json`
- `apps/worker/railway.elevators.json` uniquement si l’ordre/ensemble doit être aligné
- `.railway/railway.ts`
- `scripts/package.json`
- `scripts/railway-watch-patterns.test.ts` (nouveau)
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `railway.json`, déjà sûr avec `/apps/api/**` et `/packages/**`, sauf si le test
  révèle qu’il a dérivé avant exécution ; dans ce cas STOP au lieu de l’élargir
  silencieusement.
- Les commandes de build/start, healthchecks, schedules, régions et politiques de restart.
- Les ressources, domaines, volumes et variables définis dans `.railway/railway.ts`.
- Les valeurs d’environnement ou secrets Railway.
- Le code des apps/packages et leurs manifestes, hormis l’ajout du script test
  dans `scripts/package.json`.
- L’ajout, la suppression ou le déploiement du service fountains lui-même.

## Git

- Branche recommandée : `codex/018-track-railway-runtime-dependencies`.
- Commits logiques, par exemple
  `fix(railway): watch workspace runtime dependencies`.
- Ne pas pousser, appliquer l’IaC ni déclencher de déploiement sans demande explicite.

## Étapes

### 1. Écrire la matrice de dépendances avant de changer les patterns

Dans le nouveau `scripts/railway-watch-patterns.test.ts`, définir une matrice
explicite, proche des services, qui décrit les invariants :

| Configuration                        | Source applicative requise | Packages requis                            | Fichier config requis                                         |
| ------------------------------------ | -------------------------- | ------------------------------------------ | ------------------------------------------------------------- |
| `railway.marketing.json`             | `/apps/marketing/**`       | `/packages/contract/**`                    | `/railway.marketing.json`                                     |
| `railway.disruptions.json`           | `/apps/api/**`             | `/packages/**`                             | `/railway.disruptions.json`                                   |
| `railway.gtfs.json`                  | `/apps/worker/**`          | `/packages/contract/**`, `/packages/db/**` | `/railway.gtfs.json`                                          |
| `railway.toilets.json`               | idem worker                | idem                                       | `/railway.toilets.json`                                       |
| `railway.fountains.json`             | idem worker                | idem                                       | `/railway.fountains.json`                                     |
| `apps/worker/railway.elevators.json` | idem worker                | idem                                       | le fichier doit au minimum être couvert par `/apps/worker/**` |

Charger chaque JSON avec `Bun.file(...).json()` et comparer par inclusion, pas
par ordre strict. Ajouter deux assertions sur `.railway/railway.ts`, lu comme
texte et découpé entre les déclarations `viaMarketing`/`workerCronBuild` :

- le bloc marketing contient `/packages/contract/**` ;
- le bloc worker commun contient contract et db.

Le test ne doit pas importer/exécuter l’IaC, car cela pourrait initialiser le
SDK Railway. Il ne doit lire aucune variable d’environnement.

Ajouter `"test": "bun test"` aux scripts de `@via/scripts`, afin que le test
rejoigne le gate racine `turbo run test`.

**Vérifier** : `bun test scripts/railway-watch-patterns.test.ts` → le test échoue
sur l’état initial en nommant au moins l’omission marketing. Conserver cette
preuve, puis passer à l’étape 2.

### 2. Corriger le marketing dans les deux sources de configuration

Ajouter exactement `"/packages/contract/**"` :

- au tableau `build.watchPatterns` de `railway.marketing.json` ;
- au tableau `viaMarketing.build.watchPatterns` de `.railway/railway.ts`.

Garder tous les patterns existants, notamment `bun.lock`, `package.json`,
`turbo.json`, `patches` et le fichier Railway. Ne remplacer pas le pattern
ciblé par `/packages/**` sans raison : le site ne dépend actuellement que du
contrat parmi les workspaces `packages`.

**Vérifier** : `bun test scripts/railway-watch-patterns.test.ts` → l’assertion
marketing passe ; les éventuels échecs restants concernent les autres lignes de
la matrice.

### 3. Aligner les variantes worker sans toucher aux crons

Ajouter `/packages/contract/**` aux JSON GTFS, toilettes et fountains afin
qu’ils reflètent `workerCronBuild` et le fichier elevators. Préserver :

- leurs `startCommand` distinctes ;
- leurs schedules ;
- leurs pre-deploy migrations ;
- le nouveau service/import fountains ;
- l’ordre fonctionnel des patterns déjà présents.

Ne pas retirer `/packages/contract/**` du bloc IaC sous prétexte que le manifeste
worker n’importe aujourd’hui que `@via/db` : le commentaire de factorisation
documente une divergence passée et fixe ici une politique commune aux crons.

**Vérifier** : le test ciblé → toutes les lignes worker passent ; puis la
commande de parsing JSON sort 0.

### 4. Remplacer la liste fragile du job disruptions par sa fermeture réelle

Dans `railway.disruptions.json`, remplacer les deux patterns partiels
`/apps/api/src/jobs/**` et `/apps/api/src/routers/lines/disruptions/**` par
`/apps/api/**`. Remplacer `/packages/db/**` par `/packages/**`, cohérent avec le
typecheck de tout `@via/api` et ses dépendances workspace.

Ne modifier aucune autre clé du fichier. Ce choix déclenche quelques builds de
cron supplémentaires lors de changements API sans impact runtime, mais évite
qu’un changement de `env.ts`, `redis.ts`, `http/`, `time/` ou du contrat laisse
le job sur un ancien commit.

**Vérifier** : `bun test scripts/railway-watch-patterns.test.ts` → tous les tests passent.

### 5. Vérifier la parité IaC, les fichiers utilisateur et le gate racine

Comparer manuellement le bloc marketing JSON/IaC et le bloc worker commun avec
les JSON. Le test assure les ensembles minimaux ; la review doit repérer un
schedule ou une commande accidentellement modifiés.

Vérifier aussi que `.railway/railway.ts` contient toujours `viaFountainsCron`,
que le resource array l’inclut et que `railway.fountains.json` existe.

**Vérifier** :

```bash
rg -n 'viaFountainsCron|railway\.fountains\.json' .railway/railway.ts
bunx tsc --ignoreConfig --noEmit --skipLibCheck --module Preserve --moduleResolution bundler --target ESNext .railway/railway.ts
bun run typecheck
bun run test
```

Résultat attendu : les occurrences fountains sont présentes et toutes les
commandes sortent 0. Le résumé Turbo doit maintenant inclure la tâche test de
`@via/scripts`.

## Plan de test

- Nouveau `scripts/railway-watch-patterns.test.ts` : parse tous les JSON,
  compare les patterns minimaux et inspecte sans exécuter les deux blocs IaC.
- Le test doit échouer avec un message contenant le fichier et le pattern
  manquant, pour qu’une future dépendance soit rapide à diagnostiquer.
- Ajouter la tâche test à `scripts/package.json` rend ce contrôle transitif au
  `bun run test` racine.
- Typecheck explicite de `.railway/railway.ts`, car le package scripts ne couvre
  pas le dossier `.railway`.
- Parsing JSON en une commande pour détecter virgule ou tableau mal formé.
- Aucune connexion à Railway et aucun déploiement dans les tests.

## Critères de fin

- [ ] Marketing surveille `/packages/contract/**` dans le JSON et dans l’IaC.
- [ ] Tous les JSON worker respectent le même minimum que `workerCronBuild`.
- [ ] Disruptions surveille tout `apps/api` et tous les packages utilisés par son build.
- [ ] Chaque configuration se surveille elle-même ou est couverte par son arbre source.
- [ ] Le test de patterns est exécuté par le gate racine et passe.
- [ ] Tous les JSON se parsèrent et l’IaC typechecke.
- [ ] `bun run typecheck` et `bun run test` sortent 0.
- [ ] Le service, le fichier et le script fountains préexistants sont intacts.
- [ ] Aucun schedule, start command, secret, domaine ou ressource n’a changé.
- [ ] Aucun fichier hors périmètre n’est modifié, hormis le statut dans `plans/README.md`.

## Conditions STOP

Arrêter et remonter le problème si :

- Railway n’utilise plus les fichiers JSON/IaC cités ou le service pointe vers
  une autre configuration dans l’environnement réel ;
- une nouvelle source d’autorité génère automatiquement les JSON et rend une
  édition manuelle éphémère ;
- le diff fountains présent à la rédaction a disparu ou a été remplacé par un
  changement concurrent non réconcilié ;
- une dépendance workspace réelle ne peut pas être représentée par les patterns
  documentés sans surveiller tout le dépôt ;
- valider les patterns exige d’appliquer l’IaC ou de déclencher un déploiement ;
- le test racine devient dépendant d’un accès réseau/Railway ;
- un test/typecheck échoue deux fois après correction raisonnable ;
- un fichier hors périmètre doit être modifié.

## Notes de maintenance

- À chaque ajout de dépendance `workspace:*` dans un service déployé, mettre à
  jour dans le même commit ses watch patterns et la matrice de test.
- Les patterns sont une optimisation de déploiement, donc un léger excès de
  rebuild est préférable à un service silencieusement obsolète. L’excès ne doit
  toutefois pas devenir un `/**` sans justification.
- En review, comparer les JSON et `.railway/railway.ts`; leur duplication est la
  principale source de dérive restante.
- Si Railway permet plus tard de partager/générer ces configs depuis l’IaC,
  remplacer la duplication dans un plan dédié et simplifier le test à cette
  source unique.
