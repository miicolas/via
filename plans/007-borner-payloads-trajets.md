# Plan 007 : Borner les corps HTTP et les graphes de trajet renvoyés par les clients

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/api/src/app.ts apps/api/src/http/request-body-limit.ts apps/api/src/http/request-body-limit.test.ts packages/contract/src/journeys/schema.ts packages/contract/src/journeys/schema.test.ts packages/contract/src/journey-shares/schema.ts packages/contract/src/journey-shares/schema.test.ts apps/via/via/Shared/Networking/OpenAPI/openapi.json apps/via/via/Shared/Networking/OpenAPI/GeneratedSources/Types.swift`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP. L’exécution normale de
> `plans/003-supprimer-donnees-privees-des-journaux.md` aura remplacé
> `logger()` par le logger sûr : cette dérive précise est attendue et doit être
> conservée. **Ne jamais annuler les ajouts tarifaires
> non commités présents lors de la rédaction** : `journeyFareSchema`, le champ
> optionnel `journey.fare` et leurs artefacts OpenAPI/Swift doivent survivre.

## Statut

- **Priorité** : P1
- **Effort** : M
- **Risque** : MED — des maxima trop bas rejetteraient un trajet réel long ; des maxima trop hauts ne protégeraient pas le parseur
- **Dépend de** : `plans/003-supprimer-donnees-privees-des-journaux.md`
- **Catégorie** : sécurité / performance
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Les endpoints de partage et de choix d’un départ acceptent un trajet complet
renvoyé par le client. Le corps est lu avant toute limite globale et les tableaux
imbriqués `sections`, `geometry`, `stops` et `warnings` n’ont pas de maximum.
Un client admis par la clé extractible de l’app peut donc faire allouer, valider
et parfois persister un graphe arbitrairement grand avant que son quota soit
appliqué.

La cible pose deux défenses indépendantes : un plafond de 1 Mio au bord Hono,
puis un schéma d’entrée borné pour les trajets aller-retour client. Les schémas
de sortie du planificateur restent inchangés, et les nouvelles limites deviennent
visibles dans OpenAPI. Les ajouts tarifaires en cours sont du travail utilisateur
préexistant : ils doivent être conservés, jamais réinitialisés.

## État actuel

### Fichiers et responsabilités

- `apps/api/src/app.ts` — monte les surfaces `/api`, `/rpc` et `/public` sans limite de corps.
- `packages/contract/src/journeys/schema.ts` — définit le trajet privé et le réutilise comme entrée de `departure-choices`.
- `packages/contract/src/journey-shares/schema.ts` — réutilise le même trajet dans le snapshot de création.
- `apps/api/src/routers/journey-shares/router.ts` — applique le quota seulement après le parsing oRPC (`:12-23`).
- `apps/api/src/routers/journey-shares/service.ts` — persiste le snapshot JSONB (`:85-94`).
- `apps/via/via/Shared/Networking/OpenAPI/` — artefacts générés, jamais édités à la main.

### Extraits à reconnaître

`apps/api/src/app.ts:28-33` ne pose aucun plafond :

```ts
const app = new Hono<AppEnv>();

app.use(requestId());
app.use(logger());
app.use("/api/*", compress());
app.use("/rpc/*", compress());
```

`packages/contract/src/journeys/schema.ts:167-183` laisse les deux tableaux de
section ouverts :

```ts
export const journeySectionSchema = z.object({
  /** Stable inside one journey revision; older payloads omit it. */
  id: z.string().optional(),
  type: journeySectionTypeSchema,
  durationSeconds: z.number().int().nonnegative(),
  from: z.object({ name: z.string(), coordinate: coordinateSchema }),
  to: z.object({ name: z.string(), coordinate: coordinateSchema }),
  departureAt: z.iso.datetime({ offset: true }).optional(),
  arrivalAt: z.iso.datetime({ offset: true }).optional(),
  /** Published timetable, when the realtime estimate differs. */
  scheduledDepartureAt: z.iso.datetime({ offset: true }).optional(),
  scheduledArrivalAt: z.iso.datetime({ offset: true }).optional(),
  geometry: z.array(coordinateSchema),
  route: journeyRouteSchema.optional(),
  direction: z.string().optional(),
  platform: z.string().optional(),
  stops: z.array(journeyStopSchema).default([]),
```

`packages/contract/src/journeys/schema.ts:194-212`, dans l’état de travail au
2026-08-29, contient le tarif à préserver et le tableau de warnings ouvert :

```ts
export const journeyFareSchema = z.object({
  /** Integer minor units keep money exact across JSON and every client. */
  amountInCents: z.number().int().nonnegative(),
  currency: z.literal('EUR'),
});

export const journeySchema = z.object({
  id: z.string(),
  qualifier: journeyQualifierSchema,
  durationSeconds: z.number().int().nonnegative(),
  walkingDurationSeconds: z.number().int().nonnegative(),
  transferCount: z.number().int().nonnegative(),
  departureAt: z.iso.datetime({ offset: true }),
  arrivalAt: z.iso.datetime({ offset: true }),
  status: journeyStatusSchema,
  warnings: z.array(z.string()),
  /** Omitted when the planner cannot price the route, notably on the GTFS fallback. */
  fare: journeyFareSchema.optional(),
```

`packages/contract/src/journeys/schema.ts:241-252` laisse également le tableau
de sections ouvert :

```ts
  /** A live PMR warning; one report warns, two distinct reports can exclude. */
  wheelchairReport: z
  .object({
    stationName: z.string(),
    label: z.string(),
    reporterCount: z.number().int().positive(),
    confidence: z.enum(['observed', 'confirmed']),
    expiresAt: z.iso.datetime({ offset: true }),
  })
  .optional(),
  sections: z.array(journeySectionSchema).min(1),
});
```

`packages/contract/src/journeys/schema.ts:282-293` et
`packages/contract/src/journey-shares/schema.ts:23-27` acceptent ce graphe sans
spécialisation d’entrée :

```ts
export const journeyDepartureChoicesInputSchema = z.object({
  journey: journeySchema,
  destination: journeyDestinationSchema,
  policy: journeyPlanningPolicySchema.default({
    requiredModes: [],
    excludedModes: [],
    preferredModes: [],
    requiresAccessibleStations: false,
    requiresOperationalElevators: false,
  }),
  selection: journeyDepartureSelectionSchema.optional(),
});

export const journeyShareCreateInputSchema = z.object({
  snapshot: journeyShareSnapshotSchema,
  idempotencyKey: z.uuid(),
});
```

Le middleware Hono installé fournit déjà `bodyLimit({ maxSize, onError })` dans
`hono/body-limit`. L’enveloppe d’erreur du dépôt se construit avec
`errorBody(c, code, message)` dans `apps/api/src/http/errors.ts:24-35` ; le 413
doit suivre cette convention et conserver `requestId`.

## Commandes utiles

| But                     | Commande                                                                                                                                                                       | Résultat attendu                     |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------ |
| Tests de contrat ciblés | `bun test packages/contract/src/journeys/schema.test.ts packages/contract/src/journey-shares/schema.test.ts`                                                                   | tous passent                         |
| Test limite HTTP        | `bun test apps/api/src/http/request-body-limit.test.ts`                                                                                                                        | tous passent                         |
| Tests contract/API      | `bun run --filter=@via/contract test && bun run --filter=@via/api test`                                                                                                        | exit 0                               |
| Régénérer le client     | `bun run generate:ios-api`                                                                                                                                                     | exit 0 ; artefacts générés cohérents |
| Vérifier OpenAPI        | `bun run check:openapi`                                                                                                                                                        | `OpenAPI document is up to date`     |
| Typecheck               | `bun run typecheck`                                                                                                                                                            | 6 tâches réussies                    |
| Build iOS               | `xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug -destination 'generic/platform=iOS Simulator' VIA_API_CLIENT_KEY=improve-audit-placeholder build` | exit 0, `BUILD SUCCEEDED`            |

## Périmètre

### Fichiers autorisés

- `apps/api/src/app.ts`
- `apps/api/src/http/request-body-limit.ts` (nouveau)
- `apps/api/src/http/request-body-limit.test.ts` (nouveau)
- `packages/contract/src/journeys/schema.ts`
- `packages/contract/src/journeys/schema.test.ts` (nouveau)
- `packages/contract/src/journey-shares/schema.ts`
- `packages/contract/src/journey-shares/schema.test.ts` (nouveau)
- `apps/via/via/Shared/Networking/OpenAPI/openapi.json` (généré uniquement)
- `apps/via/via/Shared/Networking/OpenAPI/GeneratedSources/Types.swift` (généré uniquement, seulement si le générateur le modifie)
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- Les handlers, services, quotas et tables JSONB : la validation doit arrêter le
  payload avant eux.
- Les schémas de réponse `journeySchema` et `journeysResponseSchema` : un trajet
  calculé par le serveur ne doit pas devenir invalide par effet de bord.
- Les limites des réponses du planificateur IDFM/GTFS.
- Toute suppression ou réécriture des ajouts `journeyFareSchema` / `fare` et de
  leurs usages non commités.
- Une compression de requête, un upload, une nouvelle dépendance ou un changement
  des formes JSON au-delà des contraintes `maxItems`.
- Toute édition manuelle des artefacts OpenAPI/Swift.

## Git

- Branche recommandée : `codex/007-bound-journey-payloads`.
- Commit recommandé : `fix(api): bound client journey payloads`.
- Ne jamais utiliser une commande de restauration sur
  `packages/contract/src/journeys/schema.ts` ; elle effacerait du travail
  utilisateur non commité.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Écrire les tests aux frontières exactes

Créer des fixtures minimales valides à partir du schéma vivant, tarif optionnel
compris. Définir et exporter depuis `journeys/schema.ts` une constante fermée
`JOURNEY_CLIENT_LIMITS` avec ces valeurs :

- `sections: 32` ;
- `geometryPointsPerSection: 4_096` ;
- `stopsPerSection: 256` ;
- `warnings: 32`.

Dans `journeys/schema.test.ts`, caractériser le futur schéma d’entrée client :
chaque collection passe exactement à la borne et échoue à borne + 1. Vérifier
qu’un trajet contenant `fare: { amountInCents: 250, currency: 'EUR' }` est
toujours accepté et restitué.

Dans `journey-shares/schema.test.ts`, vérifier que le snapshot de création
utilise ces limites, tout en conservant `schemaVersion`, locale, fuseau et clé
d’idempotence. Tester au moins un dépassement de géométrie à l’intérieur d’une
section, pas seulement le nombre de sections.

Créer `request-body-limit.test.ts` autour d’une petite app Hono et d’un handler
qui consomme réellement le corps avec `await c.req.arrayBuffer()` et compte ses
appels. Couvrir les deux branches du middleware installé :

- avec `Content-Length`, un corps de 1 Mio atteint le handler et un corps qui
  annonce `1 Mio + 1 octet` est rejeté avant lui ;
- sans `Content-Length`, fournir un `ReadableStream` découpé en plusieurs chunks
  et vérifier la même frontière à 1 Mio puis `1 Mio + 1 octet`.

Dans les deux cas trop grands, exiger un 413, l’enveloppe
`error.code === 'payload_too_large'` et un `requestId`, sans exécuter le handler.
Le cas streamé est obligatoire : il prouve qu’un client ne contourne pas la
limite en omettant la taille déclarée.

**Vérifier** : les trois nouveaux fichiers de test échouent uniquement parce
que les limites n’existent pas encore.

### 2. Créer un schéma borné réservé aux entrées client

Dans `journeys/schema.ts`, construire un `journeyClientPayloadSchema` à partir
des champs existants, sans modifier `journeySchema` :

- étendre `journeySectionSchema` pour borner `geometry` et `stops` ;
- étendre `journeySchema` pour borner `warnings` et remplacer `sections` par le
  tableau de sections bornées avec `.min(1).max(32)` ;
- garder tous les autres champs, notamment `fare`, strictement identiques.

Utiliser ce schéma uniquement pour
`journeyDepartureChoicesInputSchema.journey`. Dans
`journey-shares/schema.ts`, créer une variante bornée du snapshot pour
`journeyShareCreateInputSchema.snapshot`, mais conserver
`journeyShareSnapshotSchema` pour la lecture des lignes existantes et les
réponses. Ainsi, le plan ne requalifie pas un ancien snapshot de base comme
`corrupt`.

Les types inférés d’entrée doivent rester assignables à `Journey`; ne pas créer
une deuxième forme métier ni dupliquer le champ tarifaire.

**Vérifier** : tests de contrat ciblés → tous passent ;
`bun run --filter=@via/contract typecheck` → exit 0.

### 3. Poser le plafond avant les routeurs

Créer `request-body-limit.ts` avec `MAX_REQUEST_BODY_BYTES = 1_048_576` et un
middleware construit avec `bodyLimit`. Son `onError` retourne
`c.json(errorBody(c, 'payload_too_large', 'Request body exceeds 1 MiB.'), 413)`.
Le message est statique et ne reprend ni taille déclarée, ni corps, ni header.

Dans `app.ts`, monter ce même middleware sur `/api/*`, `/rpc/*` et `/public/*`
immédiatement après `requestId()` et avant le `requestLogger` livré par le plan
003, client gate, auth et oRPC. Préserver ce logger sûr et ne jamais réintroduire
`hono/logger`. Le middleware Hono doit traiter aussi bien `Content-Length` que les corps streamés ;
ne pas réimplémenter sa lecture.

**Vérifier** : test HTTP ciblé puis suite API complète → tous passent.

### 4. Régénérer OpenAPI sans perdre les tarifs

Exécuter `bun run generate:ios-api`. Examiner le diff généré : il doit ajouter
les `maxItems` d’entrée attendus et conserver le champ `fare` ainsi que
`amountInCents`/`EUR`. Ne modifier ni `openapi.json` ni `Types.swift` à la main.

**Vérifier** :

```bash
bun run check:openapi
rg -n 'fare|amountInCents' apps/via/via/Shared/Networking/OpenAPI/openapi.json apps/via/via/Shared/Networking/OpenAPI/GeneratedSources/Types.swift
```

Résultats attendus : document à jour et occurrences tarifaires présentes.

### 5. Exécuter la non-régression complète

**Vérifier** :

```bash
bun run --filter=@via/contract test
bun run --filter=@via/api test
bun run typecheck
xcodebuild -project apps/via/via.xcodeproj -scheme via -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  VIA_API_CLIENT_KEY=improve-audit-placeholder build
```

Résultat attendu : toutes les commandes sortent avec le code 0 et le build iOS
affiche `BUILD SUCCEEDED`.

## Plan de test

- Test de chaque limite à N et N + 1, avec fixture minimale pour éviter une
  explosion mémoire dans la suite elle-même.
- Test imbriqué : dépassement d’une géométrie et de stops dans une section.
- Test des deux consommateurs : `departure-choices` et création d’un partage.
- Régression explicite du tarif optionnel préexistant.
- Test Hono de 413 avec handler non appelé, enveloppe standard et request ID.
- Suite OpenAPI et build Swift pour vérifier que la contrainte générée reste
  consommable par l’app.

## Critères de fin

- [ ] Tout corps des surfaces `/api`, `/rpc` et `/public` est plafonné à 1 Mio avant parsing/auth métier.
- [ ] Le 413 utilise l’enveloppe standard et n’échoe aucune donnée client.
- [ ] Les deux entrées client bornent sections, géométrie, stops et warnings aux valeurs documentées.
- [ ] Les schémas de sortie privés restent inchangés.
- [ ] `journeyFareSchema`, `journey.fare` et leurs artefacts générés sont présents.
- [ ] Les tests N/N+1, suites contract/API, OpenAPI, typecheck et build iOS passent.
- [ ] Aucun service, quota, modèle DB ou fichier hors périmètre n’est modifié.

## Conditions STOP

Arrêter et remonter le problème si :

- les ajouts `journeyFareSchema` ou `journey.fare` ont disparu, divergent de
  l’extrait ou seraient écrasés par une régénération ;
- une fixture ou donnée de production documentée dépasse une des bornes proposées ;
- Hono consomme le corps avant que oRPC puisse le lire, ou n’applique pas le
  plafond aux requêtes sans `Content-Length` ;
- la génération modifie la forme Swift métier au-delà de contraintes de schéma ;
- borner les entrées exige de modifier `journeySchema` de sortie ou une table ;
- un test échoue deux fois après correction raisonnable ;
- un fichier hors périmètre devient nécessaire.

## Notes de maintenance

- Les deux niveaux sont complémentaires : le plafond octets protège le parseur,
  les maxima Zod protègent l’algorithme et documentent le contrat.
- Toute nouvelle collection imbriquée ajoutée au trajet doit être examinée dans
  `journeyClientPayloadSchema`, sans l’exposer automatiquement comme entrée non
  bornée.
- Une hausse de limite doit être justifiée par la taille d’un trajet réel et
  accompagnée d’un test de taille sérialisée.
- Les artefacts OpenAPI restent générés ; en review, rejeter toute correction
  manuelle qui masque un drift.
