# Plan 003 : Ne jamais journaliser les recherches ni les coordonnées privées

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/api/src/app.ts apps/api/src/http/fetch-json-or-null.ts apps/api/src/http/fetch-json-or-null.test.ts apps/api/src/http/request-logger.ts apps/api/src/http/request-logger.test.ts`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : M
- **Risque** : MED — il faut conserver des journaux exploitables sans réintroduire une URL, une query string ou une erreur amont non bornée
- **Dépend de** : aucun autre plan
- **Catégorie** : sécurité / confidentialité
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Le middleware d’accès Hono reçoit aujourd’hui l’URL complète. Or les endpoints
GET de recherche et de calcul de trajet transportent dans leur query string le
texte saisi, les noms d’adresses et des coordonnées précises. Les erreurs réseau
des upstreams non-PRIM peuvent en plus contenir leur URL complète dans l’objet
`Error` journalisé. Une recherche réussie et une panne BAN peuvent donc toutes
deux copier des données de déplacement privées dans les journaux de production.

La cible conserve méthode, **gabarit de route** sans valeur dynamique, statut,
durée et identifiant de requête, puis réduit les erreurs upstream à un événement
structuré fermé. Aucun
header, corps, paramètre, URL ou message d’exception tiers ne doit atteindre le
sink de logs.

## État actuel

### Fichiers et responsabilités

- `apps/api/src/app.ts` — installe les middlewares globaux avant les trois surfaces HTTP.
- `apps/api/src/http/fetch-json-or-null.ts` — enveloppe les appels JSON tolérants aux pannes et journalise les échecs non-PRIM.
- `apps/api/src/http/fetch-json-or-null.test.ts` — caractérise déjà la télémétrie PRIM bornée.
- `packages/contract/src/search/schema.ts` — prouve que `/search` reçoit requête et position dans l’URL ; fichier de contexte uniquement.
- `packages/contract/src/journeys/schema.ts` — prouve que `/journeys` aplatit adresses et coordonnées dans l’URL ; fichier de contexte uniquement.

### Extraits à reconnaître

`apps/api/src/app.ts:28-32` monte le logger Hono sans politique de
redaction :

```ts
const app = new Hono<AppEnv>();

app.use(requestId());
app.use(logger());
app.use("/api/*", compress());
```

`packages/contract/src/search/schema.ts:12-25` place le texte et la position
dans la query string du GET :

```ts
export const searchInputSchema = z.object({
  q: z.string().trim().min(1).max(200),
  /**
   * Where the user is, if known. It rides along for two jobs: geographic
   * prioritization of address results, and `distanceMeters` on every result.
   * Absent when location permission is denied — results then carry no distance.
   */
  latitude: z.coerce.number().min(-90).max(90).optional(),
  longitude: z.coerce.number().min(-180).max(180).optional(),
  limit: z.int().min(1).max(20).default(10),
  /** Restrict the unified search to Vélib' stations. */
  bikeStationsOnly: queryBooleanSchema.optional(),
});
```

`packages/contract/src/journeys/schema.ts:31-37` documente le même
aplatissement pour la destination, et `:48-54` porte les champs sensibles :

```ts
/**
 * GET /journeys carries its input in the query string, and deepObject
 * serialization only supports one level of primitives — swift-openapi-runtime
 * refuses nested objects before the request is even sent. So the wire shape
 * flattens `coordinate` into `latitude`/`longitude` and parses back into
 * {@link journeyDestinationSchema} server-side; handlers never see the flat form.
 * Query values arrive as strings, hence the explicit coercion.
 */
```

```ts
  z.object({
  kind: z.literal('address'),
  id: z.string().min(1),
  name: z.string().min(1),
  context: z.string().optional(),
  latitude: z.coerce.number(),
  longitude: z.coerce.number(),
  }),
```

`apps/api/src/http/fetch-json-or-null.ts:101` et `:118` transmettent l’objet
d’erreur inconnu à `console.error` :

```ts
console.error(`${logLabel} indisponible`, cause);
```

À l’inverse, la télémétrie PRIM existante constitue le précédent à suivre :
`fetch-json-or-null.ts:124-143` construit un objet fermé avec `provider`,
`product`, `outcome`, `durationMs` et éventuellement `httpStatus`, puis le
sérialise. Ses tests vérifient déjà que le domaine et le corps secrets sont
absents (`fetch-json-or-null.test.ts:8-58`).

## Commandes utiles

| But                | Commande                                                                                         | Résultat attendu               |
| ------------------ | ------------------------------------------------------------------------------------------------ | ------------------------------ |
| Tests HTTP ciblés  | `bun test apps/api/src/http/request-logger.test.ts apps/api/src/http/fetch-json-or-null.test.ts` | tous les tests passent         |
| Tests API          | `bun run --filter=@via/api test`                                                                 | exit 0, tous les tests passent |
| Typecheck API      | `bun run --filter=@via/api typecheck`                                                            | exit 0, aucune erreur          |
| Typecheck monorepo | `bun run typecheck`                                                                              | 6 tâches réussies              |

## Périmètre

### Fichiers autorisés

- `apps/api/src/app.ts`
- `apps/api/src/http/request-logger.ts` (nouveau)
- `apps/api/src/http/request-logger.test.ts` (nouveau)
- `apps/api/src/http/fetch-json-or-null.ts`
- `apps/api/src/http/fetch-json-or-null.test.ts`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- Les méthodes GET et les formes du contrat : ce plan corrige la frontière de
  journalisation, pas le transport OpenAPI.
- Les métriques PRIM existantes, leurs noms de produit et leur politique de
  fallback.
- `error-handler.ts` et les journaux métiers sans URL : ne pas lancer une
  refonte générale de l’observabilité.
- Les secrets, `.env` et `Secrets.xcconfig` : ne jamais les ouvrir ni les
  reproduire.
- L’ajout d’un fournisseur de télémétrie ou d’une dépendance de logging.

## Git

- Branche recommandée : `codex/003-sanitize-request-logs`.
- Commits logiques, style observé : `fix(api): redact private request data from logs`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Caractériser la fuite avec des sentinelles

Créer `request-logger.test.ts`. Construire une petite application `Hono<AppEnv>`
avec `requestId()`, le futur middleware et un sink injecté qui accumule les
événements sans toucher `console`. Envoyer une URL comprenant des valeurs
sentinelles non réelles, par exemple un texte de recherche, un nom de rue et
deux coordonnées réservées au test. Ajouter une route
`/public/journey-shares/:token` et un token sentinelle afin de prouver que le
gabarit, pas la capability, est journalisé.

Les assertions doivent exiger :

- un seul événement par requête ;
- méthode, gabarit de route (`/public/journey-shares/:token`, jamais la valeur
  du token), statut, durée entière positive ou nulle et
  `requestId` présents ;
- aucune query string et aucune sentinelle dans `JSON.stringify(event)` ;
- le même invariant sur une réponse 4xx ;
- aucune valeur de header ou de corps ajoutée à l’événement.

Ajouter à `fetch-json-or-null.test.ts` deux cas non-PRIM injectant un recorder
de test : JSON invalide et rejet réseau dont le `Error.message` contient une
URL avec une sentinelle. Les deux doivent retourner `null`, conserver un
`outcome` distinct et ne jamais restituer la sentinelle.

**Vérifier** : lancer les tests ciblés. Ils doivent échouer uniquement parce
que le nouveau middleware/recorder n’existe pas encore ; toute autre cause est
une condition STOP.

### 2. Remplacer le logger d’accès par un événement fermé

Créer `request-logger.ts` avec une factory de middleware dont le sink est
injectable pour les tests et vaut en production une sérialisation JSON vers
`console.log`. Définir explicitement le type de l’événement :

- `event: 'http_request'` ;
- `method` ;
- `route`, obtenu après `await next()` avec `routePath(c, -1)` depuis
  `hono/route`, afin de journaliser `:token`/`:id` plutôt que leur valeur ;
- `status` ;
- `durationMs` ;
- `requestId` lorsqu’il existe.

Le middleware doit appeler `await next()` et émettre exactement une fois dans
un `finally`, afin qu’un chemin d’erreur conserve sa trace. Si aucune route
finale n’est disponible, utiliser une valeur fermée (`/api/*`, `/rpc/*`,
`/public/*` ou `unmatched`) déterminée sans recopier les segments du chemin.
Le calcul de durée utilise une horloge monotone. Le sink ne reçoit jamais
`c.req.path`, `c.req.url`, `c.req.query()`, les headers, le corps, la réponse ou
un objet `Error`.

Dans `app.ts`, retirer l’import `hono/logger`, conserver `requestId()` avant le
logger, puis monter le nouveau middleware global au même endroit. Ne changer
ni l’ordre des gates, ni CORS, ni compression.

**Vérifier** : `bun test apps/api/src/http/request-logger.test.ts` → tous les
tests passent et la recherche `rg -n 'hono/logger|logger\(\)' apps/api/src/app.ts`
ne retourne rien.

### 3. Fermer les événements d’échec upstream non-PRIM

Dans `fetch-json-or-null.ts`, introduire un événement non-PRIM fermé avec les
seuls champs utiles : nom statique `logLabel`, résultat parmi
`http_error | timeout | aborted | network_error | invalid_json`, durée et
statut HTTP éventuel. Ajouter un recorder optionnel injecté par les tests ; le
recorder de production sérialise seulement cet événement.

Ne jamais intégrer à cet objet : `url`, `cause`, `cause.message`, stack trace,
headers, corps de réponse ou query string. Garder les différences de fallback :
la fonction retourne toujours `null` sur ces pannes et la télémétrie PRIM
continue d’emprunter son chemin actuel. Un échec du recorder ne doit pas changer
la réponse métier, conformément au `try/catch` de `recordTelemetry`.

**Vérifier** : `bun test apps/api/src/http/fetch-json-or-null.test.ts` → les cas
PRIM existants et les nouveaux cas non-PRIM passent ; chaque assertion de
sentinelle confirme son absence.

### 4. Exécuter la non-régression API

Exécuter les tests et typechecks complets du package, puis le typecheck racine.
Ne mettre à jour aucun snapshot de test qui réintroduirait une URL complète.

**Vérifier** : `bun run --filter=@via/api test && bun run --filter=@via/api typecheck && bun run typecheck`
→ toutes les commandes sortent avec le code 0.

## Plan de test

- `request-logger.test.ts` : succès, réponse 4xx, présence du request ID,
  exactement un événement et absence de toutes les sentinelles de query/header.
- `fetch-json-or-null.test.ts` : conserver les deux tests PRIM ; ajouter JSON
  invalide et erreur réseau non-PRIM contenant volontairement une URL privée.
- Les tests inspectent l’objet/sérialisation transmis au sink, pas seulement la
  sortie terminale, afin de rendre l’invariant stable.
- Le test de fuite doit échouer si un futur champ `url`, `query`, `headers`,
  `cause` ou `message` non contrôlé est ajouté.

## Critères de fin

- [ ] `bun run --filter=@via/api test` et `typecheck` sortent avec le code 0.
- [ ] `bun run typecheck` réussit ses 6 tâches.
- [ ] `app.ts` n’importe plus `hono/logger`.
- [ ] Un log d’accès contient méthode, gabarit de route, statut, durée et request ID, sans query, token ni segment dynamique.
- [ ] Les erreurs BAN et autres upstreams non-PRIM ne journalisent ni URL ni objet `Error` brut.
- [ ] Les tests injectent des sentinelles de texte, adresse et coordonnées et prouvent leur absence des logs.
- [ ] La télémétrie PRIM et tous les fallbacks métier restent inchangés.
- [ ] Aucun fichier hors périmètre n’est modifié, hormis le statut du plan dans `plans/README.md`.

## Conditions STOP

Arrêter et remonter le problème si :

- Hono ne permet plus de récupérer le dernier gabarit de route après `next()` ;
- obtenir le statut final exige de consommer ou cloner le corps de réponse ;
- un sink de production existant dépend explicitement du format texte du
  middleware `hono/logger` ;
- rendre l’erreur upstream exploitable semble exiger un message tiers, une URL
  ou un corps de réponse : définir d’abord une taxonomie fermée, ne pas les
  recopier ;
- une sentinelle apparaît encore dans un événement après deux corrections
  raisonnables ;
- la correction demande un changement de contrat ou un fichier hors périmètre.

## Notes de maintenance

- La liste de champs du log HTTP est une allowlist. Tout nouveau champ doit être
  dérivé d’une valeur bornée créée par Via, jamais d’une valeur client.
- `logLabel` doit rester une constante de code ; ne jamais lui passer une URL ou
  une requête utilisateur.
- En review, chercher particulièrement les variantes RPC et `/public`, car le
  middleware est global et doit leur appliquer exactement la même redaction.
- Les métriques agrégées ou traces distribuées pourront être ajoutées plus tard,
  mais elles devront réutiliser les mêmes événements fermés.
