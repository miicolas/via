# Plan 008: Mettre Next.js à niveau vers une version corrigée de l’App Router

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/marketing/package.json apps/marketing/next.config.ts bun.lock`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. Toute autre montée de version de Next,
> de React ou de la configuration de build est une condition STOP jusqu’à
> réconciliation explicite.

## Statut

- **Priorité** : P1
- **Effort** : M (montée corrective, validation des routes et du rendu de production)
- **Risque** : MED — une version corrective de framework peut modifier le build, le cache ou les types générés
- **Dépend de** : aucun autre plan
- **Catégorie** : security / migration
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Le site marketing public utilise Next.js `16.1.1` avec l’App Router. Cette
version appartient à la plage affectée par
[GHSA-8h8q-6873-q5fj](https://github.com/advisories/GHSA-8h8q-6873-q5fj),
une consommation excessive de CPU déclenchable sans authentification sur les
endpoints React Server Components. La version corrigée indiquée par l’avis est
`16.2.5` ; le résultat attendu de ce plan est donc une version publiée de
Next.js **au moins égale à `16.2.5`**, gardée exactement alignée avec
`eslint-config-next`, sans élargir la migration à React ni au design du site.

## État actuel

### Fichiers et responsabilités

- `apps/marketing/package.json` — manifeste du site ; épingle Next et sa configuration ESLint à `16.1.1`.
- `bun.lock` — résolution reproductible du monorepo ; contient Next, ses binaires SWC et le plugin ESLint correspondants.
- `apps/marketing/next.config.ts` — configuration de production à préserver pendant la montée de version.
- `apps/marketing/src/app/` — App Router réellement exposé, dont la route dynamique de trajets partagés.

### Extraits à reconnaître avant modification

`apps/marketing/package.json:23-27` :

```json
"motion": "^12.23.26",
"next": "16.1.1",
"next-themes": "^0.4.6"
```

`apps/marketing/package.json:49-53` :

```json
"@types/react-dom": "^19",
"eslint": "^9",
"eslint-config-next": "16.1.1",
"prettier": "^3.7.4"
```

`bun.lock:946` et `bun.lock:1372` résolvent aujourd’hui exactement :

```text
eslint-config-next@16.1.1
next@16.1.1
```

`apps/marketing/next.config.ts:3-23` conserve quatre comportements à ne pas
perdre : en-tête AASA, domaine d’image Unsplash, source maps navigateur
désactivées et suppression des `console` en production.

### Contraintes à conserver

- Le gestionnaire déclaré à la racine est `bun@1.3.4`; ne pas introduire npm,
  pnpm ou un second lockfile.
- `next` et `eslint-config-next` sont épinglés sans `^`; garder une version
  exacte et identique pour les deux paquets.
- Ne pas modifier `react` ni `react-dom` (`19.2.3`) sauf si la release corrective
  choisie les déclare explicitement incompatibles. Dans ce cas, STOP.
- Ne pas accepter une prerelease, canary ou nightly pour satisfaire le seuil.
- Ne pas traiter les autres avis de `bun audit` dans ce plan : chaque montée
  indépendante doit garder son propre périmètre et ses propres tests.
- Le contrôle Prettier complet du site échoue déjà sur des fichiers sans rapport
  avec ce plan. Ne pas reformater le site ; vérifier uniquement le manifeste
  modifié.

## Commandes utiles

| But                     | Commande                                            | Résultat attendu                        |
| ----------------------- | --------------------------------------------------- | --------------------------------------- |
| Installer selon le lock | `bun install --frozen-lockfile`                     | exit 0, aucune modification du lock     |
| Tests marketing         | `bun run --filter=@via/marketing test`              | tous les tests passent                  |
| Typecheck marketing     | `bun run --filter=@via/marketing typecheck`         | exit 0, aucune erreur TypeScript        |
| Lint marketing          | `bun run --filter=@via/marketing lint`              | exit 0                                  |
| Build production        | `bun run --filter=@via/marketing build`             | exit 0, toutes les routes sont générées |
| Format ciblé            | `bunx prettier --check apps/marketing/package.json` | exit 0                                  |
| Audit ciblé             | `bun audit --production`                            | ne liste pas `GHSA-8h8q-6873-q5fj`      |

## Référence conseillée

- Lire l’avis officiel
  [GHSA-8h8q-6873-q5fj](https://github.com/advisories/GHSA-8h8q-6873-q5fj)
  et les notes de version officielles entre `16.1.1` et la version retenue
  avant de modifier le manifeste.
- Si plusieurs versions stables satisfont le seuil, préférer la plus petite
  version stable encore maintenue qui corrige tous les avis Next actuellement
  remontés par `bun audit`; ne pas franchir une version majeure dans ce plan.

## Périmètre

### Fichiers autorisés

- `apps/marketing/package.json`
- `bun.lock`
- `apps/marketing/next.config.ts` uniquement si une adaptation documentée par
  la release corrective est strictement nécessaire
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `react`, `react-dom`, TanStack Query, nuqs, MapLibre et les autres dépendances.
- Le contenu, le style, la navigation et les composants du site.
- Les configurations Railway et les variables d’environnement.
- La correction des écarts Prettier préexistants.
- Les autres avis de dépendances, notamment l’extraction GTFS traitée par le
  plan 009.

## Git

- Branche recommandée : `codex/008-upgrade-nextjs-security`.
- Commits logiques, par exemple
  `fix(marketing): upgrade Next.js past the RSC DoS advisory`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Choisir une release corrective stable et compatible

Consulter la release officielle choisie et confirmer simultanément :

1. version stable, non canary ;
2. version `>=16.2.5` ;
3. même majeure `16` ;
4. compatibilité déclarée avec React `19.2.3`, Node/Bun et l’App Router ;
5. absence de l’avis `GHSA-8h8q-6873-q5fj` pour cette version ;
6. absence d’un autre avis Next de sévérité haute que cette même version
   laisserait ouvert alors qu’une release corrective 16.x est disponible.

Noter la version exacte retenue dans le message de commit et dans la PR. Ne pas
sélectionner `16.2.5` par automatisme si un avis ultérieur impose déjà une
version 16.x plus récente au moment de l’exécution.

**Vérifier** : `bun info next version` → une version stable est retournée ; la
version choisie respecte les six critères ci-dessus.

### 2. Mettre à jour les deux paquets en une seule résolution Bun

Depuis la racine, mettre à jour `next` et `eslint-config-next` vers **la même
version exacte**, par exemple si la version retenue est `16.2.5` :

```bash
bun add --cwd apps/marketing --exact next@16.2.5
bun add --cwd apps/marketing --dev --exact eslint-config-next@16.2.5
```

Remplacer `16.2.5` dans ces commandes si l’étape 1 a établi une version 16.x
corrective plus récente. Examiner ensuite le diff de `apps/marketing/package.json`
et `bun.lock`. Le lock peut mettre à jour les dépendances transitives de Next,
mais il ne doit pas modifier les versions directes sans rapport.

**Vérifier** :

```bash
bun -e 'const p = await Bun.file("apps/marketing/package.json").json(); if (p.dependencies.next !== p.devDependencies["eslint-config-next"]) process.exit(1); const [major, minor, patch] = p.dependencies.next.split(".").map(Number); if (major !== 16 || minor < 2 || (minor === 2 && patch < 5)) process.exit(1)'
```

Résultat attendu : exit 0. Puis `bun install --frozen-lockfile` doit sortir 0
sans modifier `bun.lock`.

### 3. Appliquer uniquement les adaptations de compatibilité requises

Lancer le typecheck et le build avant de toucher la configuration. Si les deux
passent, laisser `apps/marketing/next.config.ts` inchangé. Si Next signale une
option supprimée ou renommée, appliquer seulement l’adaptation explicitement
documentée dans les notes de version, en conservant les quatre comportements
listés dans « État actuel ».

Ne pas profiter de la migration pour activer React Compiler, modifier le cache,
changer les images distantes ou déplacer les providers.

**Vérifier** :

```bash
bun run --filter=@via/marketing typecheck
bun run --filter=@via/marketing build
```

Résultat attendu : deux exits 0 ; le build liste notamment `/`, `/analytics`,
`/blog`, `/trip/[token]` et les pages marketing statiques encore présentes.

### 4. Exécuter la non-régression marketing complète

Exécuter les tests et le lint sans changer une assertion fonctionnelle pour
masquer une régression. Les tests de partage de trajet, blog et statut doivent
continuer à utiliser Bun ; aucun runner supplémentaire n’est nécessaire.

**Vérifier** :

```bash
bun run --filter=@via/marketing test
bun run --filter=@via/marketing lint
bunx prettier --check apps/marketing/package.json
```

Résultat attendu : tous les tests passent et les trois commandes sortent 0.

### 5. Prouver la disparition de l’avis ciblé

Lancer l’audit sur la résolution finale. L’audit global peut encore signaler
des avis sans rapport ; le gate de ce plan porte sur l’absence de l’identifiant
ciblé et sur l’absence d’une résolution `next@16.1.1`.

**Vérifier** :

```bash
if bun audit --production 2>&1 | rg -q 'GHSA-8h8q-6873-q5fj'; then exit 1; fi
if rg -q 'next@16\.1\.1|eslint-config-next@16\.1\.1' bun.lock; then exit 1; fi
```

Résultat attendu : exit 0 pour les deux contrôles.

## Plan de test

- Aucun test unitaire nouveau n’est requis : le changement porte uniquement
  sur la résolution du framework.
- `bun run --filter=@via/marketing test` caractérise les helpers et contenus
  déjà couverts.
- `bun run --filter=@via/marketing typecheck` valide les types Next générés.
- `bun run --filter=@via/marketing build` est le test ciblé indispensable : il
  compile les Server Components, les métadonnées, les routes dynamiques et les
  handlers de flux.
- `bun audit --production` et les contrôles `rg` prouvent que l’ancienne
  résolution vulnérable n’est plus dans le lockfile.

## Critères de fin

- [ ] `next` et `eslint-config-next` ont exactement la même version stable 16.x, `>=16.2.5`.
- [ ] `bun.lock` ne contient plus `next@16.1.1` ni `eslint-config-next@16.1.1`.
- [ ] L’audit ne remonte plus `GHSA-8h8q-6873-q5fj`.
- [ ] `bun install --frozen-lockfile` sort 0 et ne modifie rien.
- [ ] Tests, typecheck, lint et build marketing sortent 0.
- [ ] Les quatre comportements de `next.config.ts` sont conservés.
- [ ] React, React DOM et les dépendances sans rapport n’ont pas été modifiés.
- [ ] Aucun fichier hors périmètre n’est modifié, hormis le statut dans `plans/README.md`.

## Conditions STOP

Arrêter et remonter le problème si :

- aucune release stable Next 16.x disponible ne corrige l’avis ;
- la version corrective impose une montée majeure de React, Node, Bun ou Next ;
- les notes de version exigent une migration du routeur, du cache ou du rendu
  qui dépasse une adaptation mécanique de configuration ;
- `bun audit` continue de rattacher `GHSA-8h8q-6873-q5fj` à la version retenue ;
- le diff du lockfile met à jour des dépendances directes sans rapport et une
  seconde résolution ciblée ne l’évite pas ;
- le build ou les tests échouent deux fois après une correction raisonnable ;
- un fichier hors périmètre doit être modifié.

## Notes de maintenance

- Next et `eslint-config-next` doivent continuer à monter ensemble et rester
  épinglés à la même version exacte.
- En review, vérifier le lockfile pour repérer une seconde copie de Next ou des
  binaires SWC restés à `16.1.1`.
- Les avis de framework sont souvent corrigés par paliers. À la prochaine mise
  à niveau, relire l’audit complet plutôt que de ne vérifier que cet identifiant.
- Ce plan ne prétend pas rendre `bun audit` entièrement vert ; il ferme une
  vulnérabilité publique et directement atteignable, sans mélanger les autres
  migrations.
