# Plan 017: Aligner le site et le README sur une API strictement première partie

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- README.md apps/marketing/src/constants/navigation.ts apps/marketing/src/constants/marketing-pages.ts apps/marketing/src/constants/community-page.ts apps/marketing/src/constants/first-party-positioning.test.ts apps/marketing/src/components/marketing/marketing-detail-page.tsx apps/marketing/src/components/marketing/marketing-page-visual.tsx apps/marketing/src/components/sections/community/community-participation-section.tsx`
> L’ADR accepté est la source d’autorité. Si son statut ou sa décision a changé,
> ou si un autre ADR l’a remplacé, arrêter avant toute modification de contenu.

## Statut

- **Priorité** : P2
- **Effort** : M (retrait de deux pages produit, réécriture d’une tuile et tests de positionnement)
- **Risque** : MED — suppression de routes publiques déjà indexables et décision de message produit
- **Dépend de** : `plans/011-centralize-launch-destinations.md` (les deux plans modifient `constants/navigation.ts`; conserver la configuration de lancement du plan 011)
- **Catégorie** : docs / bug
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

L’ADR 0003 réserve explicitement l’API aux clients de première partie afin de
protéger les quotas PRIM, OpenAI et la base. Le site public promet pourtant une
« API temps réel », des webhooks, un catalogue de connecteurs et invite la
communauté à « détourner l’API » ; le README désigne même les tiers comme
appelants REST. Ces promesses ne correspondent ni à la porte client ni au
produit livré. La cible de ce plan est un message sans ambiguïté : Metyro utilise
une API interne pour son app et son site, tandis que seules quelques projections
`/public` écrites à la main alimentent des pages précises — aucune offre API ou
intégration tierce n’est commercialisée.

## État actuel

### Décision d’architecture à respecter

`docs/adr/0003-api-reservee-aux-clients-de-premiere-partie.md:12-18` :

```text
1. Une porte d’entrée unique ... montée au-dessus de tous les routeurs.
2. L’app présente un secret partagé ... sur /api et /rpc.
3. Le site est reconnu par son origine ... et par VIA_SITE_CLIENT_KEYS côté serveur.
5. /api/openapi.json passe derrière la porte.
```

L’amendement `:22-28` autorise seulement des exceptions étroites :

```text
chaque route /public est une projection écrite à la main,
jamais une réponse du contrat transmise telle quelle.
```

La décision est marquée `accepté` à la ligne 3. Elle n’est pas une suggestion à
réinterpréter dans une page marketing.

### Promesses qui divergent aujourd’hui

`README.md:118-121` :

```markdown
| `/api` | REST at the contract's paths, described by `/api/openapi.json` | iOS app and third parties |
| `/rpc` | oRPC | internal typed integrations |
```

`apps/marketing/src/constants/navigation.ts:13-22` expose deux entrées produit :

```ts
{ label: "Intégrations", href: "/integrations" },
{ label: "API", href: "/api" },
```

Elles sont également répétées dans le footer aux lignes 63-66.

`apps/marketing/src/constants/marketing-pages.ts:84-166` définit :

```ts
api: {
  eyebrow: "API temps réel",
  description: "... réponses précises, versionnées ... pour votre produit ...",
  primaryAction: { label: "Explorer l’API", href: "/help#api-et-integrations" },
  // dont une carte « Les événements arrivent ... » avec l’icône webhook
},
integrations: {
  description: "Metyro fait voyager le signal ... vers ... votre propre logique.",
  secondaryAction: { label: "Utiliser l’API", href: "/api" },
}
```

`apps/marketing/src/constants/community-page.ts:48-52` va plus loin :

```ts
api: {
  title: "Détournez l’API vers un usage inattendu.",
  hint: "Une installation, un outil d’accessibilité, une expérience locale ...",
  action: { label: "Explorer l’API", href: "/api" },
}
```

Deux copies subsistent même hors de ces pages produit :

- `marketing-pages.ts:327` autorise conditionnellement « l’API lorsqu’elle est
  mise à disposition » dans les conditions ;
- `marketing-pages.ts:419-423` propose dans l’aide « Je construis avec les
  données Metyro » puis renvoie vers `/api`.

Les composants `marketing-detail-page.tsx` et `marketing-page-visual.tsx`
possèdent des branches spécifiques aux slugs/signaux `api` et `integrations`.
Les retirer des données sans nettoyer ces records laisserait le typecheck en
échec ou du code mort trompeur.

### Conventions à conserver

- Les pages génériques sont générées à partir de `marketingPageSlugs`; un slug
  absent renvoie `notFound()` dans `app/(marketing)/[slug]/page.tsx`.
- Le contenu marketing est typé par `as const satisfies`; laisser TypeScript
  conduire le nettoyage exhaustif des records par slug.
- Les routes publiques de statut de lignes, partage de trajet et vote restent
  des exceptions nécessaires au site. Ne pas supprimer `/public` ni modifier
  le backend dans un plan de contenu.
- La page `/analytics` décrit les données ouvertes IDFM réellement consommées ;
  elle peut rester dans la navigation produit.
- Le plan 011 peut avoir remplacé le libellé de l’action `#download` dans
  `navigation.ts`. Préserver son import et sa dérivation.

## Commandes utiles

| But                 | Commande                                                                                                                                                                      | Résultat attendu                                        |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| Test positionnement | `bun test apps/marketing/src/constants/first-party-positioning.test.ts`                                                                                                       | tous les tests passent                                  |
| Tests marketing     | `bun run --filter=@via/marketing test`                                                                                                                                        | tous passent                                            |
| Typecheck           | `bun run --filter=@via/marketing typecheck`                                                                                                                                   | exit 0                                                  |
| Lint                | `bun run --filter=@via/marketing lint`                                                                                                                                        | exit 0                                                  |
| Build               | `bun run --filter=@via/marketing build`                                                                                                                                       | exit 0, `/api` et `/integrations` ne sont plus générées |
| Recherche ciblée    | `rg -n -e 'iOS app and third parties' -e 'Explorer l.API' -e 'Utiliser l.API' -e 'Détournez l.API' -e 'href: "/api"' -e 'href: "/integrations"' README.md apps/marketing/src` | aucune sortie                                           |

## Périmètre

### Fichiers autorisés

- `README.md`
- `apps/marketing/src/constants/navigation.ts`
- `apps/marketing/src/constants/marketing-pages.ts`
- `apps/marketing/src/constants/community-page.ts`
- `apps/marketing/src/constants/first-party-positioning.test.ts` (nouveau)
- `apps/marketing/src/components/marketing/marketing-detail-page.tsx`
- `apps/marketing/src/components/marketing/marketing-page-visual.tsx`
- `apps/marketing/src/components/sections/community/community-participation-section.tsx`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `docs/adr/0003-api-reservee-aux-clients-de-premiere-partie.md` — décision à appliquer, pas à réécrire dans ce plan.
- `apps/api/**`, `packages/contract/**`, le client gate, CORS, les clés et quotas.
- Les projections `/public` existantes et leurs consommateurs marketing.
- Une future offre développeurs, portail de clés, webhooks ou documentation OpenAPI publique.
- La page `/analytics` et les affirmations factuelles sur les données ouvertes IDFM.
- Les CTA de lancement du plan 011, même lorsqu’ils vivent dans `navigation.ts`.
- Les conditions juridiques hors des copies directement structurées dans les fichiers autorisés.

## Git

- Branche recommandée : `codex/017-align-first-party-api-messaging`.
- Commits logiques, par exemple
  `fix(marketing): remove unsupported public API promises`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Confirmer que l’ADR accepté est toujours l’intention produit

Lire l’ADR 0003 entièrement et rechercher un ADR plus récent qui le remplace.
Demander confirmation à l’opérateur uniquement si une source plus récente ou
un travail actif indique qu’une API publique est désormais voulue.

Deux chemins sont possibles, mais un seul appartient à ce plan :

- **première partie confirmée** : poursuivre les étapes 2 à 6 ;
- **API publique réellement souhaitée** : STOP. Une nouvelle décision
  d’architecture doit d’abord remplacer l’ADR 0003 et spécifier authentification
  tierce, quotas, isolation des budgets, contrat public, versioning, support,
  documentation et conditions d’utilisation. Ne jamais « aligner » le site en
  ouvrant simplement la porte actuelle.

**Vérifier** : `rg -n 'Statut : accepté|API réservée aux clients de première partie' docs/adr/0003-api-reservee-aux-clients-de-premiere-partie.md` → les deux éléments sont présents, sans ADR successeur contradictoire.

### 2. Corriger le README sans masquer les deux transports internes

Dans la table « Two transports, one router », remplacer les appelants trompeurs
par des formulations première partie :

- `/api` — app iOS et usages explicitement approuvés des clients Metyro ;
- `/rpc` — intégrations typées internes de première partie.

Ajouter juste sous la table une phrase courte qui renvoie à l’ADR 0003 et
précise : le contrat/OpenAPI n’est pas une offre publique ; les exceptions du
site vivent sous `/public` et sont des projections manuelles. Garder le README
en anglais dans cette section, comme le texte environnant.

Ne documenter aucune clé, valeur de secret ou procédure de contournement de la
porte client.

**Vérifier** :

```bash
if rg -q 'iOS app and third parties' README.md; then exit 1; fi
rg -n 'first-party|/public|ADR 0003' README.md
```

Résultat attendu : aucun ancien libellé et au moins une explication première
partie avec l’exception `/public`.

### 3. Retirer les pages produit API et intégrations de la génération

Dans `marketing-pages.ts` :

1. retirer `"api"` et `"integrations"` de `marketingPageSlugs` ;
2. retirer les deux définitions complètes de `marketingPages` ;
3. supprimer de `MarketingIconName` seulement les icônes devenues réellement
   inutilisées après recherche (`webhook`, `plug`, etc.) ; ne pas faire un grand
   nettoyage cosmétique ;
4. conserver sans changement fonctionnel `security`, `terms` et `help`.

Deux corrections de cohérence sont néanmoins requises dans les contenus
conservés :

- dans l’utilisation acceptable, remplacer la future offre API implicite par
  une phrase conforme à l’ADR : l’accès automatisé au contrat interne n’est pas
  proposé au public et les personnes utilisent seulement les interfaces
  officielles prévues ;
- dans l’aide, remplacer la carte « Je construis avec les données Metyro » et
  son lien `/api` par une aide réellement disponible, par exemple « Je veux
  signaler une information incorrecte », avec la marche à suivre existante et
  sans inventer de formulaire.

La route dynamique rendra alors 404 pour ces anciens slugs et ne les émettra
plus dans `generateStaticParams`. Ne pas les rediriger vers `/help` ou
`/analytics` : une redirection conserverait l’impression qu’une offre existe.

Dans `marketing-detail-page.tsx`, retirer les clés `api` et `integrations` de
`pageStatements` et `closingCopy`. Dans `marketing-page-visual.tsx`, supprimer
les deux visualisations et branches de switch correspondantes, ainsi que leurs
imports devenus inutiles.

**Vérifier** : `bun run --filter=@via/marketing typecheck` → exit 0 ; aucun
record exhaustif ne réclame les anciens slugs.

### 4. Retirer ces offres de toutes les navigations

Dans `constants/navigation.ts`, retirer `/api` et `/integrations` des groupes
desktop/mobile et footer. Garder « Analytics » comme entrée produit et conserver
les ressources Blog, Communauté, Sécurité et Aide.

Si le plan 011 est déjà exécuté, garder son import de configuration de lancement
et son libellé dérivé pour `primaryAction`; ne pas restaurer le texte statique
« Télécharger ».

**Vérifier** :

```bash
if rg -n 'href: "/(api|integrations)"' apps/marketing/src/constants/navigation.ts; then exit 1; fi
```

Résultat attendu : exit 0.

### 5. Remplacer l’invitation communautaire par une contribution réellement livrée

La page communauté reste utile, mais sa tuile « Détournez l’API » doit cesser de
vendre un accès absent. Renommer la donnée `participation.api` en
`participation.dataQuality` et la reformuler autour d’un comportement existant :
signaler une donnée de station qui ne correspond pas au terrain. Cible de sens :

- titre : « Signalez une donnée qui ne correspond pas au quai. » ;
- explication : ascenseur, sortie, équipement ou état observé, avec lieu et
  heure pour permettre une vérification ;
- action : la vraie page `/help`, sans promesse d’accès programmatique.

Dans `community-participation-section.tsx`, renommer `ApiVisual` en une
visualisation de qualité de donnée. Retirer `GET /v1/elevators` et le faux JSON
public. Afficher par exemple trois lignes sémantiques « source officielle »,
« observé sur place », « à vérifier », en réutilisant les styles de carte
existants et sans inventer une soumission automatique côté backend.

Garder la grille, les autres tuiles et l’action de vote inchangées.

**Vérifier** :

```bash
if rg -n 'Détournez l.API|Explorer l.API|GET /v1/elevators|participation\.api' \
  apps/marketing/src/constants/community-page.ts \
  apps/marketing/src/components/sections/community/community-participation-section.tsx; then exit 1; fi
```

Résultat attendu : exit 0.

### 6. Ajouter une barrière de régression sur les promesses publiques

Créer `constants/first-party-positioning.test.ts` avec `bun:test`. Importer les
données plutôt que de tester seulement des regex :

- `marketingPageSlugs` n’inclut ni `api` ni `integrations` ;
- `getMarketingPage("api")` et `getMarketingPage("integrations")` renvoient
  `undefined` ;
- aucune navigation ni entrée footer ne pointe vers ces deux routes ;
- le contenu communauté sérialisé ne contient ni « Explorer l’API », ni
  « Détournez l’API », ni `GET /v1/` ;
- le contenu `marketingPages` sérialisé ne contient aucun `href: "/api"`, aucune
  invitation à obtenir un accès et aucune offre conditionnelle « API lorsqu’elle
  est mise à disposition » ;
- le README lu via une URL relative à `import.meta.url` ne contient plus
  `iOS app and third parties` et contient le terme `first-party` près de la
  table des transports.

Tester les promesses précises, pas toute occurrence du mot « API » : le README
doit continuer à expliquer l’architecture interne et les pages de sécurité
peuvent employer ce vocabulaire sans vendre un produit développeur.

**Vérifier** : `bun test apps/marketing/src/constants/first-party-positioning.test.ts` → tous les tests passent.

### 7. Valider le rendu et l’absence des anciennes routes

Exécuter toute la suite marketing. Dans la sortie du build, `/api` et
`/integrations` ne doivent plus apparaître parmi les routes générées. Vérifier
manuellement les menus desktop/mobile/footer et le bento communauté : aucun
trou de grille, aucun lien cassé et aucune offre développeur.

**Vérifier** :

```bash
bun run --filter=@via/marketing test
bun run --filter=@via/marketing typecheck
bun run --filter=@via/marketing lint
bun run --filter=@via/marketing build
rg -n 'iOS app and third parties|Explorer l.API|Utiliser l.API|Détournez l.API|href: "/(api|integrations)"' README.md apps/marketing/src
```

Résultat attendu : les quatre premières commandes sortent 0 ; la dernière ne
produit aucune sortie et sort 1 parce qu’aucun motif interdit n’est trouvé.

## Plan de test

- Nouveau `first-party-positioning.test.ts`, construit avec `bun:test` comme
  `journey-share-token.test.ts` : slugs, résolution de page, navigation,
  communauté et phrase README.
- Typecheck exhaustif : la réduction de `MarketingPageSlug` doit forcer la
  suppression des copies dans `pageStatements`, `closingCopy` et le switch de
  visualisation.
- Build Next : les routes supprimées ne sont plus pré-rendues.
- Recherche de chaînes ciblée : les promesses exactes et hrefs anciens ne
  subsistent pas, sans interdire la documentation interne du mot API.
- Vérification responsive manuelle des menus et de la grille communauté.

## Critères de fin

- [ ] L’ADR 0003 reste la décision acceptée et aucun ADR plus récent ne la remplace.
- [ ] Le README décrit `/api` et `/rpc` comme des transports première partie.
- [ ] Le README explique l’exception `/public` par projection manuelle.
- [ ] Les slugs, contenus, visuels et navigations `/api` et `/integrations` ont disparu.
- [ ] La tuile communauté décrit un signalement de qualité de donnée réellement possible.
- [ ] Aucun CTA ne promet d’explorer, utiliser ou détourner une API publique.
- [ ] Le test de positionnement, toute la suite, le typecheck, le lint et le build passent.
- [ ] La configuration de lancement du plan 011 est préservée dans `navigation.ts`.
- [ ] Aucun fichier hors périmètre n’est modifié, hormis le statut dans `plans/README.md`.

## Conditions STOP

Arrêter et remonter le problème si :

- l’opérateur confirme qu’une API publique ou des intégrations tierces sont
  réellement voulues ; dans ce cas, exiger un nouvel ADR qui remplace 0003 avant
  toute modification du gate, du contrat ou des pages ;
- un ADR plus récent autorise déjà une offre publique avec un périmètre précis ;
- une intégration cliente tierce réelle et supportée est découverte ;
- retirer `/api` ou `/integrations` exige une redirection commerciale ou une
  politique SEO qui n’a pas été décidée ;
- remplacer la tuile communauté exige de construire un nouveau flux de
  signalement plutôt que de pointer vers l’aide existante ;
- le plan 011 a modifié `navigation.ts` et sa configuration ne peut pas être
  conservée pendant le retrait des deux entrées ;
- un test/build échoue deux fois après correction raisonnable ;
- un fichier hors périmètre doit être modifié.

## Notes de maintenance

- Toute future page développeur doit commencer par une décision produit et un
  ADR de remplacement, jamais par la publication du contrat interne.
- Une route `/public` supplémentaire doit continuer à projeter ses champs à la
  main comme l’exige l’amendement ; ce plan ne transforme pas `/public` en API
  générale.
- En review, rechercher surtout les liens indirects dans la communauté, le
  footer et les records de fermeture de page : supprimer le slug seul ne retire
  pas la promesse.
- Si une stratégie de redirection des anciennes URLs devient nécessaire après
  observation de trafic réel, la traiter séparément avec une destination qui ne
  suggère pas une offre inexistante.
