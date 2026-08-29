# Plan 010 : Rendre durable la version du cache après un import GTFS

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/worker/src/network-cache-version.ts apps/worker/src/network-cache-version.test.ts apps/worker/src/gtfs-import-metadata.ts apps/worker/src/gtfs-import-metadata.test.ts apps/worker/src/import-gtfs.ts apps/api/src/routers/departures/network-version.ts apps/api/src/routers/departures/network-version.test.ts apps/api/src/routers/departures/handlers/get-station-departures.ts apps/api/src/routers/network/handlers/get-rail-map.ts apps/api/src/routers/index.ts apps/api/src/app.ts`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP. Les modifications attendues de
> `app.ts` par les plans 003 et 007 — logger sûr puis limite de corps — doivent
> être conservées ; ce plan ne touche que l’appel de version du cache.

## Statut

- **Priorité** : P1
- **Effort** : M
- **Risque** : MED — la version protège plusieurs caches Redis et mémoires ; un mauvais fallback peut servir des données incohérentes pendant une panne DB
- **Dépend de** : `plans/007-borner-payloads-trajets.md`
- **Catégorie** : bug / architecture
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Après un import réussi, le worker enregistre d’abord le hash du feed dans
PostgreSQL puis tente un `INCR` Redis qui peut échouer silencieusement. Le prochain
run voit alors le même hash, conclut « unchanged » et ne retente jamais cette
invalidation. Les instances API gardent donc leur version et peuvent servir
indéfiniment une rail map ou des snapshots station obsolètes.

La cible fait de `import_meta` la source durable de la génération réseau. La
fin d’import écrit le hash et une nouvelle génération dans **la même transaction
PostgreSQL** ; si cette transaction échoue, le hash précédent force le run
suivant à réimporter. L’API relit cette génération au plus une fois par minute,
conserve sa dernière valeur connue lors d’une panne et n’utilise plus Redis
comme autorité de cohérence.

## État actuel

### Fichiers et responsabilités

- `apps/worker/src/import-gtfs.ts` — décide `imported`/`unchanged` et finalise le hash.
- `apps/worker/src/network-cache-version.ts` — tente un compteur Redis après commit.
- `packages/db/src/schema.ts:560-570` — `import_meta(key, value, updated_at)`, table durable déjà disponible ; contexte, pas de migration.
- `apps/api/src/routers/departures/network-version.ts` — met en cache local la version Redis pendant 60 secondes.
- `apps/api/src/app.ts`, `routers/index.ts`, `get-station-departures.ts` et `get-rail-map.ts` — consommateurs de la version.
- `apps/api/src/http/versioned-payload-cache.test.ts:96-106` — précédent : une nouvelle version doit invalider le payload mémoire.

### Extraits à reconnaître

`apps/worker/src/network-cache-version.ts:3-18` fait de Redis une écriture
best-effort :

```ts
const TRANSIT_NETWORK_VERSION_KEY = "transit:network:version";

export async function bumpTransitNetworkCacheVersion() {
  const redisURL = process.env.REDIS_URL;
  if (!redisURL) return;

  const redis = new RedisClient(redisURL);
  try {
    await redis.incr(TRANSIT_NETWORK_VERSION_KEY);
  } catch (cause) {
    console.error("[worker] could not bump transit cache version", cause);
  } finally {
    redis.close();
  }
}
```

`apps/worker/src/import-gtfs.ts:503-509` lit d’abord le hash et peut court-circuiter :

```ts
const [stored] = await db
  .select()
  .from(importMeta)
  .where(eq(importMeta.key, GTFS_FEED_HASH_KEY));
if (!force && stored?.value === feedHash) {
  console.log('GTFS feed unchanged since the last completed import — nothing to do (--force to reimport).');
  return { status: 'unchanged', feedHash };
} else {
```

Puis `apps/worker/src/import-gtfs.ts:526-533` sépare irréversiblement le hash
et l’invalidation :

```ts
await db
  .insert(importMeta)
  .values({ key: GTFS_FEED_HASH_KEY, value: feedHash })
  .onConflictDoUpdate({
    target: importMeta.key,
    set: { value: feedHash, updatedAt: new Date() },
  });
await bumpTransitNetworkCacheVersion();
```

`apps/api/src/routers/departures/network-version.ts:3-27` lit uniquement
Redis et retombe sur une constante :

```ts
const NETWORK_VERSION_KEY = "transit:network:version";
const FALLBACK_VERSION = "1";
const LOCAL_VERSION_TTL_MS = 60_000;

let localVersion: { value: string; expiresAt: number } | undefined;

export async function transitNetworkCacheVersion(
  redis: RedisClient,
): Promise<string> {
  const now = Date.now();
  if (localVersion && localVersion.expiresAt > now) return localVersion.value;

  let version = FALLBACK_VERSION;
  try {
    const value = await redis.get<unknown>(NETWORK_VERSION_KEY);
    if (typeof value === "number" || typeof value === "string")
      version = String(value);
  } catch (cause) {
    console.error("[departures] transit network version unavailable", cause);
  }
  localVersion = { value: version, expiresAt: now + LOCAL_VERSION_TTL_MS };
  return version;
}
```

`packages/db/src/schema.ts:560-570` garantit qu’aucune migration n’est
nécessaire :

```ts
export const importMeta = pgTable("import_meta", {
  key: text("key").primaryKey(),
  value: text("value").notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});
```

Les enrichissements accessibilité, ascenseurs, affluence, toilettes et
wayfinding appellent eux aussi `bumpTransitNetworkCacheVersion()` sans argument.
Cette interface publique doit rester valide : leur bump devient durable par le
nouveau défaut PostgreSQL, même si leur transaction métier n’est pas refondue
ici.

## Commandes utiles

| But                          | Commande                                                                                                             | Résultat attendu                                                                                         |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Tests worker ciblés          | `bun test apps/worker/src/network-cache-version.test.ts apps/worker/src/gtfs-import-metadata.test.ts`                | tous passent                                                                                             |
| Test API ciblé               | `bun test apps/api/src/routers/departures/network-version.test.ts apps/api/src/http/versioned-payload-cache.test.ts` | tous passent                                                                                             |
| Tests packages               | `bun run --filter=@via/worker test && bun run --filter=@via/api test`                                                | exit 0                                                                                                   |
| Typecheck                    | `bun run typecheck`                                                                                                  | 6 tâches réussies                                                                                        |
| Intégration GTFS optionnelle | `bun run --filter=@via/worker test:gtfs-integration`                                                                 | passe si `GTFS_INTEGRATION_DATABASE_URL` pointe vers une base jetable ; sinon test explicitement skipped |

## Périmètre

### Fichiers autorisés

- `apps/worker/src/network-cache-version.ts`
- `apps/worker/src/network-cache-version.test.ts` (nouveau)
- `apps/worker/src/gtfs-import-metadata.ts` (nouveau)
- `apps/worker/src/gtfs-import-metadata.test.ts` (nouveau)
- `apps/worker/src/import-gtfs.ts`
- `apps/api/src/routers/departures/network-version.ts`
- `apps/api/src/routers/departures/network-version.test.ts` (nouveau)
- `apps/api/src/routers/departures/handlers/get-station-departures.ts`
- `apps/api/src/routers/network/handlers/get-rail-map.ts`
- `apps/api/src/routers/index.ts`
- `apps/api/src/app.ts`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- Les tables de transit, leur import massif, dérivations, `ANALYZE` et `VACUUM`.
- Une migration : `import_meta` suffit.
- La politique de cache des départs, la TTL Redis des snapshots et le cache de
  payload gzip.
- Les transactions des importeurs d’enrichissement autres que GTFS ; ils
  héritent du stockage durable, mais leur commit métier n’est pas regroupé ici.
- Le nettoyage de l’ancienne clé Redis : elle devient orpheline et inoffensive.
- Les changements en cours dans `apps/api/src/routers/network/queries.ts` et les
  fichiers de fontaines ; ne pas les toucher.

## Git

- Branche recommandée : `codex/010-durable-transit-cache-version`.
- Commit recommandé : `fix(transit): persist cache generation with GTFS metadata`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Introduire une génération durable et testable côté worker

Dans `network-cache-version.ts`, supprimer `RedisClient` et `REDIS_URL`.
Conserver la clé logique `transit:network:version`, mais l’écrire dans
`import_meta`. Une génération est une valeur opaque unique créée par
`randomUUID()` ; ne pas faire un read-modify-write numérique susceptible de
perdre une concurrence.

La fonction garde le nom `bumpTransitNetworkCacheVersion` et accepte en option
le store/transaction Drizzle ainsi qu’une génération injectée pour le test. Sans
argument, elle utilise `db`. Avec la transaction passée par le finaliseur GTFS,
elle écrit dans cette transaction. L’écriture fait un upsert de `value` et
`updatedAt`. Contrairement au code actuel, une erreur doit se propager : un bump
durable qui échoue n’est pas un succès d’import.

Dans `network-cache-version.test.ts`, utiliser une seam de store sans base
réelle et vérifier : clé exacte, génération fournie, upsert sur conflit,
propagation d’erreur et deux générations par défaut distinctes. Ne journaliser
aucune URL de base.

**Vérifier** : test worker ciblé de cette étape → tous les tests passent ;
`rg -n 'RedisClient|REDIS_URL' apps/worker/src/network-cache-version.ts` ne
retourne rien.

### 2. Grouper hash et génération dans une seule transaction finale

Créer `gtfs-import-metadata.ts` avec une fonction
`finalizeGtfsImportMetadata(feedHash, adapters?)`. Elle ouvre une seule
`db.transaction`, upsert le hash sous la clé existante `gtfs:feed:sha256`, puis
appelle `bumpTransitNetworkCacheVersion(tx)` avant que la transaction se ferme.
L’adapter de transaction et les deux écritures doivent être injectables pour le
test sans PostgreSQL.

Déplacer et exporter `GTFS_FEED_HASH_KEY` depuis ce nouveau module, puis
l’importer dans `import-gtfs.ts` aussi bien pour la lecture initiale que pour la
finalisation. Il ne doit rester qu’une déclaration de la chaîne
`gtfs:feed:sha256`.

Dans le test, prouver que :

- le hash et la génération reçoivent le même objet transaction ;
- le commit simulé n’est marqué réussi qu’après les deux écritures ;
- un échec du bump rejette le finaliseur et ne marque pas le commit ;
- le hash vide est refusé avant d’ouvrir une transaction.

Dans `import-gtfs.ts`, remplacer le bloc d’upsert + bump par ce finaliseur.
Conserver la règle `unchanged`, le verrou, et l’ordre import → maintenance →
dérivations → transaction de métadonnées. Si la transaction finale échoue, la
fonction doit rejeter et ne jamais retourner `{ status: 'imported' }`.

**Vérifier** : tests `gtfs-import-metadata` et worker complet → exit 0.

### 3. Lire PostgreSQL comme autorité côté API

Refondre `routers/departures/network-version.ts` autour d’une factory testable,
par exemple `createTransitNetworkVersionReader({ read, now, ttlMs })`. Le reader
de production sélectionne `import_meta.value` pour
`transit:network:version`. Garder une TTL locale de 60 secondes afin de ne pas
interroger PostgreSQL à chaque requête.

Politique de panne explicite :

- avec une dernière valeur locale, la conserver même expirée et journaliser un
  événement d’indisponibilité borné ; renouveler alors une TTL de retry de 60
  secondes pour éviter une lecture DB et un log à chaque requête pendant la panne ;
- sans aucune valeur connue, utiliser la sentinelle `1` pour rester compatible
  avec une base pas encore initialisée et la cacher également 60 secondes ;
- une ligne absente vaut également `1` ;
- une lecture réussie remplace la valeur locale et renouvelle la TTL.

Retirer le paramètre Redis de `transitNetworkCacheVersion`. Adapter uniquement
ses quatre call sites dans `app.ts`, `get-station-departures.ts`,
`get-rail-map.ts` et `routers/index.ts`. Ne modifier aucune construction de clé
de snapshot. Dans `app.ts`, préserver strictement l’ordre `requestId` → limite
de corps → logger sûr → gates livré par les plans 003/007.

Dans `network-version.test.ts`, injecter horloge et reader pour vérifier :
lecture initiale, cache avant 60 s, refresh après 60 s, nouvelle génération,
ligne absente, panne sans cache et panne avec cache périmé.

**Vérifier** : tests API ciblés → tous passent ;
`rg -n 'transitNetworkCacheVersion\(redis\)' apps/api/src` ne retourne rien.

### 4. Vérifier l’invalidation de bout en bout au niveau des seams

Garder `versioned-payload-cache.test.ts` inchangé : son cas « a new network
version invalidates the entry » doit continuer de passer. Ajouter dans le test
du reader l’enchaînement `v1` → expiration de TTL locale → `v2`, puis vérifier
que les deux chaînes diffèrent exactement comme les namespaces de cache
l’attendent.

Si une base jetable est disponible, étendre ou exécuter le test d’intégration
GTFS pour vérifier que `gtfs:feed:sha256` et `transit:network:version` existent
après un import réussi. Ne jamais exécuter ce test contre une base partagée ou
de production.

**Vérifier** : commandes ciblées puis tests complets worker/API → code 0.

### 5. Exécuter le typecheck global

**Vérifier** : `bun run typecheck` → les 6 tâches réussissent. Puis
`git diff --name-only` ne montre que les fichiers autorisés et le statut du plan.

## Plan de test

- Worker : upsert durable, génération opaque, erreur propagée.
- Finaliseur GTFS : même transaction pour hash + génération, aucun succès
  observable si le second write échoue.
- API : cache local avec horloge injectée, refresh, absence de ligne et stale-on-error.
- Cache payload existant : changement de version invalide toujours l’entrée.
- Intégration PostgreSQL seulement sur la base jetable explicitement fournie ;
  le skip documenté n’est pas un échec du plan.

## Critères de fin

- [ ] Le worker n’utilise plus Redis pour la génération réseau.
- [ ] Hash GTFS et nouvelle génération sont écrits dans la même transaction PostgreSQL.
- [ ] Un échec de génération empêche `status: 'imported'` et laisse l’ancien hash comme signal de retry.
- [ ] L’API lit `import_meta` au plus une fois par minute et garde la dernière version connue sur panne.
- [ ] Tous les call sites utilisent la nouvelle signature sans Redis.
- [ ] Les autres importeurs peuvent toujours appeler le bump sans argument.
- [ ] Tests worker/API et typecheck monorepo passent.
- [ ] Aucune migration ni fichier hors périmètre n’est modifié.

## Conditions STOP

Arrêter et remonter le problème si :

- l’import écrit désormais son hash dans une autre transaction ou table ;
- `import_meta` n’existe pas dans l’environnement cible ou n’est pas partagé par
  worker et API ;
- regrouper le hash et la génération exige de déplacer `VACUUM` dans une
  transaction ;
- un appelant dépend de la valeur numérique de la version au lieu de son égalité ;
- une lecture PostgreSQL par minute est incompatible avec l’architecture de
  connexion réellement déployée ;
- le test d’intégration pointe vers une base non jetable ;
- un fichier de réseau actuellement modifié mais hors périmètre devient nécessaire ;
- une vérification échoue deux fois après correction raisonnable.

## Notes de maintenance

- La valeur est une génération opaque. Aucun consommateur ne doit la parser,
  l’incrémenter ou comparer son ordre.
- Tout nouveau cache dépendant du réseau doit inclure cette génération dans sa
  clé ou son mémo.
- Les importeurs d’enrichissement utilisent désormais un bump durable, mais leur
  propre écriture métier et ce bump restent deux transactions : les regrouper
  pourra faire l’objet d’un plan séparé autour de `replaceSnapshot`.
- L’ancienne clé Redis ne doit plus être relue. Son nettoyage opérationnel est
  facultatif et hors périmètre.
