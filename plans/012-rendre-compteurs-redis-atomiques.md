# Plan 012 : Rendre atomiques l’incrément et l’expiration des compteurs Redis

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/api/src/redis.ts apps/api/src/http/redis-rate-limit.ts apps/api/src/http/redis-rate-limit.test.ts apps/api/src/routers/idfm/daily-budget.ts apps/api/src/routers/natural-journeys/circuit-breaker.ts apps/api/src/routers/natural-journeys/circuit-breaker.test.ts apps/api/src/routers/departures/__fixtures__/fake-redis.ts apps/api/src/routers/departures/budget.test.ts apps/api/src/reports/rate-limiter.test.ts apps/api/src/reports/service.test.ts`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : S
- **Risque** : LOW — l’opération Redis change, mais les clés, TTL, seuils et politiques de panne restent identiques
- **Dépend de** : aucun autre plan
- **Catégorie** : bug / fiabilité
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Les fenêtres de quota réalisent aujourd’hui `INCR`, puis `EXPIRE` dans une
deuxième commande uniquement lorsque le résultat vaut 1. Si la connexion tombe
entre les deux, la clé reste sans TTL. Pour les clés non bucketées de partage ou
de signalement, cela peut refuser durablement un utilisateur ; pour les budgets
quotidiens, cela laisse des compteurs orphelins et une politique différente de
ce que le code promet.

La cible ajoute une seule primitive Redis atomique, fondée sur `EVAL`, qui
incrémente puis pose la TTL du premier hit dans le même script. Tous les compteurs
de fenêtre et budgets journaliers l’utilisent. Les compteurs bruts sans notion
d’expiration, comme la version d’un agrégat de signalements, gardent `incr`.

## État actuel

### Fichiers et responsabilités

- `apps/api/src/redis.ts` — interface Redis injectée dans toute l’API et adapter Bun ; contient déjà plusieurs scripts Lua atomiques.
- `apps/api/src/http/redis-rate-limit.ts` — primitive partagée par quotas personnels, partages, votes et signalements.
- `apps/api/src/routers/idfm/daily-budget.ts` — deuxième copie de `INCR` + `EXPIRE` pour les budgets PRIM.
- `apps/api/src/routers/natural-journeys/circuit-breaker.ts` — troisième copie pour la fenêtre de pannes OpenAI.
- `apps/api/src/routers/departures/__fixtures__/fake-redis.ts` — fake typé commun aux tests de cache et budgets.
- `apps/api/src/reports/rate-limiter.test.ts` et `service.test.ts` — fakes locaux à adapter à la nouvelle primitive.

### Extraits à reconnaître

`apps/api/src/http/redis-rate-limit.ts:8-19` sépare les deux commandes :

```ts
export async function incrementFixedWindow(
  redis: RedisClient,
  key: string,
  windowSeconds: number,
) {
  if (!Number.isInteger(windowSeconds) || windowSeconds < 1) {
    throw new Error("A rate-limit window needs a positive integer duration");
  }

  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, windowSeconds);
  return count;
}
```

`apps/api/src/routers/idfm/daily-budget.ts:25-35` duplique exactement la zone
de panne :

```ts
export async function tryConsumeDailyIdfmBudget(
  redis: RedisClient,
  { dailyBudget, now, counterKeyPrefix }: DailyIdfmBudgetInput,
): Promise<DailyIdfmBudgetDecision> {
  const { date, seconds } = parisDay(now);
  const key = `${counterKeyPrefix}:${date}`;
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, COUNTER_TTL_SECONDS);

  const ceiling = dailyBudget * (1 - SAFETY_RESERVE_RATIO);
  return {
    allowed: count <= ceiling,
    ratio: count / expectedByNow(dailyBudget, seconds),
  };
}
```

`apps/api/src/routers/natural-journeys/circuit-breaker.ts:32-44` utilise le
même invariant de TTL pour la série de pannes :

```ts
isOpen: async () => (await redis.get<string>(OPEN_KEY)) !== null,
recordSuccess: async () => {
  await redis.del(FAILURES_KEY);
},
recordFailure: async () => {
  const failures = await redis.incr(FAILURES_KEY);
  // Keep the counter from outliving a quiet period: a lone failure with no
  // follow-up should decay rather than pre-load the next trip.
  if (failures === 1) await redis.expire(FAILURES_KEY, openSeconds);
  if (failures >= failureThreshold) {
    await redis.set(OPEN_KEY, '1', { ex: openSeconds });
    await redis.del(FAILURES_KEY);
  }
},
```

`apps/api/src/redis.ts:75-92` montre la convention Lua existante : script
court, une clé comptée explicitement, arguments convertis en chaînes, résultat
normalisé par l’adapter.

```ts
compareAndExpire: async (key, expectedValue, seconds) => {
  const result = await client.send("EVAL", [
    "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('EXPIRE', KEYS[1], ARGV[2]) else return 0 end",
    "1",
    key,
    expectedValue,
    String(seconds),
  ]);
  return Number(result) === 1;
},
```

Les consommateurs de `incrementFixedWindow` sont, au commit planifié :

- `routers/journeys/rate-limit.ts` ;
- `routers/journey-shares/rate-limit.ts` ;
- `reports/rate-limiter.ts` ;
- `public/city-demand/rate-limiter.ts`.

Ils doivent hériter de l’atomicité sans changer leurs seuils ni leur choix de
fail-open/fail-closed.

## Commandes utiles

| But                | Commande                                                                                                                                                                                                                                                                                           | Résultat attendu  |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| Tests ciblés       | `bun test apps/api/src/http/redis-rate-limit.test.ts apps/api/src/routers/departures/budget.test.ts apps/api/src/routers/journeys/rate-limit.test.ts apps/api/src/routers/natural-journeys/circuit-breaker.test.ts apps/api/src/reports/rate-limiter.test.ts apps/api/src/reports/service.test.ts` | tous passent      |
| Tests API          | `bun run --filter=@via/api test`                                                                                                                                                                                                                                                                   | exit 0            |
| Typecheck API      | `bun run --filter=@via/api typecheck`                                                                                                                                                                                                                                                              | exit 0            |
| Typecheck monorepo | `bun run typecheck`                                                                                                                                                                                                                                                                                | 6 tâches réussies |

## Périmètre

### Fichiers autorisés

- `apps/api/src/redis.ts`
- `apps/api/src/http/redis-rate-limit.ts`
- `apps/api/src/http/redis-rate-limit.test.ts` (nouveau)
- `apps/api/src/routers/idfm/daily-budget.ts`
- `apps/api/src/routers/natural-journeys/circuit-breaker.ts`
- `apps/api/src/routers/natural-journeys/circuit-breaker.test.ts`
- `apps/api/src/routers/departures/__fixtures__/fake-redis.ts`
- `apps/api/src/routers/departures/budget.test.ts`
- `apps/api/src/reports/rate-limiter.test.ts`
- `apps/api/src/reports/service.test.ts`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- Les namespaces, durées, seuils et politiques de repli des quatre consommateurs.
- Le cooldown de signalement déjà atomique via `SET NX EX`.
- Les locks/cache leases qui utilisent `compareAndExpire` ou `compareAndDelete`.
- `reports/service.ts:101`, dont l’`INCR` est une version monotone sans TTL, pas
  une fenêtre de quota.
- La structure de Redis, une nouvelle dépendance ou un serveur Redis réel dans
  les tests.
- Le remplacement de tous les scripts Lua existants par une abstraction générale.

## Git

- Branche recommandée : `codex/012-atomic-redis-windows`.
- Commit recommandé : `fix(api): expire Redis counters atomically`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Caractériser la primitive atomique attendue

Créer `redis-rate-limit.test.ts` avec un faux client dont
`incrementWithExpiry(key, seconds)` enregistre un unique appel et renvoie un
compteur programmable. Tester :

- premier et deuxième hit retournés sans appel séparé à `incr` ou `expire` ;
- clé et TTL transmises sans modification ;
- un compteur ancien sans TTL reçoit une expiration au prochain hit, tandis
  qu’un compteur ayant déjà une TTL conserve son échéance initiale ;
- fenêtre 0, négative, décimale ou non finie refusée avant tout accès Redis ;
- erreur Redis propagée au consommateur, qui conserve ainsi sa politique locale.

Étendre `fake-redis.ts` avec une implémentation atomique en mémoire qui incrémente
le store et pose la TTL lors de la création **ou lorsqu’une ancienne clé n’a
plus de TTL**. Une clé qui possède déjà une TTL ne doit pas voir sa fenêtre
repoussée. Les maps `store` et `expiries` restent inspectables par les tests
existants.

**Vérifier** : le nouveau test échoue seulement parce que la méthode n’existe pas.

### 2. Ajouter `incrementWithExpiry` à l’adapter Redis

Étendre `RedisClient` avec
`incrementWithExpiry(key: string, seconds: number): Promise<number>`. Dans
l’adapter Bun, envoyer un unique `EVAL` dont le script :

1. exécute `INCR KEYS[1]` ;
2. lit `TTL KEYS[1]` et exécute `EXPIRE KEYS[1] ARGV[1]` lorsque la clé vient
   d’être créée ou n’a pas d’expiration ;
3. retourne le compteur.

Passer exactement une clé, la TTL sous forme de chaîne et normaliser la réponse
avec `Number(result)`. Ne pas interpoler la clé ou la TTL dans le texte Lua.
Conserver les méthodes `incr` et `expire`, utilisées par des opérations sans
ce même invariant.

Faire appeler cette nouvelle primitive par `incrementFixedWindow` après sa
validation existante.

**Vérifier** : `bun test apps/api/src/http/redis-rate-limit.test.ts` → tous les
tests passent ; l’implémentation de `incrementFixedWindow` ne contient plus
`redis.incr` ni `redis.expire`.

### 3. Migrer le budget journalier et le circuit breaker

Dans `daily-budget.ts`, réutiliser `incrementFixedWindow(redis, key,
COUNTER_TTL_SECONDS)` plutôt que recopier les commandes. Ne changer ni le jour
Paris, ni la réserve de 5 %, ni le calcul de ratio.

Dans `circuit-breaker.ts`, utiliser la même primitive avec `openSeconds` pour la
clé de failures. Garder `SET ... EX` pour la clé ouverte et `DEL` après succès
ou déclenchement. Ce module n’est pas un quota, mais présente exactement le même
risque de compteur immortel ; le laisser derrière créerait une quatrième
implémentation divergente.

Adapter `budget.test.ts` pour faire échouer `incrementWithExpiry` dans son cas
Redis indisponible. Ajouter une assertion sur la TTL de 48 heures du compteur
IDFM. Le test circuit breaker doit aussi vérifier la TTL de la série de failures,
pas uniquement celle de la clé ouverte.

**Vérifier** : tests budget, journey rate limit et circuit breaker → tous passent.

### 4. Mettre à jour tous les fakes sans assouplir leurs types

Ajouter la primitive atomique aux fakes de `reports/rate-limiter.test.ts` et
`reports/service.test.ts`, ou faire réutiliser `fakeRedis()` lorsque cela réduit
la duplication sans élargir le périmètre. Ne masquer aucune méthode manquante
avec un cast supplémentaire.

Exécuter les tests des signalements. Ils doivent conserver : cooldown de cinq
minutes, dix écritures utilisateur par heure, garde NAT à mille, et fail-closed
si la primitive atomique rejette.

**Vérifier** : tests ciblés de signalements → tous passent.

### 5. Prouver qu’aucune paire dangereuse ne subsiste

Rechercher les incréments directs. Le seul `redis.incr` de production acceptable
après ce plan est la version d’agrégat dans `reports/service.ts`; toute occurrence
associée à une TTL doit être migrée.

**Vérifier** :

```bash
rg -n "redis\.incr\(" apps/api/src
bun run --filter=@via/api test
bun run --filter=@via/api typecheck
bun run typecheck
```

Résultat attendu : `rg` ne montre que les incréments explicitement sans fenêtre,
puis toutes les commandes sortent avec le code 0.

## Plan de test

- Test unitaire de la seam atomique, validation de TTL et propagation d’erreur.
- Fake Redis commun reproduisant « TTL à la création ou réparation d’une clé
  orpheline, jamais renouvelée lorsqu’elle existe déjà ».
- Budgets IDFM : date Paris, réserve, ratio, TTL 48 h et panne fail-closed.
- Quota personnel : renouvellement de bucket inchangé.
- Circuit breaker : série de failures expirante, seuil et reset sur succès.
- Signalements : limites utilisateur/IP et fail-closed inchangés.
- Suite API complète pour capturer chaque fake structurellement typé.

## Critères de fin

- [ ] `RedisClient` expose une primitive `incrementWithExpiry` réalisée par un seul `EVAL`.
- [ ] `incrementFixedWindow`, le budget IDFM et le circuit breaker n’enchaînent plus `INCR` puis `EXPIRE` côté client.
- [ ] Tous les consommateurs de fenêtre gardent leurs clés, TTL, seuils et fallbacks.
- [ ] Les tests vérifient la TTL du premier hit, la réparation d’un ancien compteur sans TTL et l’absence de renouvellement aux hits suivants.
- [ ] Les fakes typés implémentent la nouvelle primitive sans cast de contournement ajouté.
- [ ] Tests API et typechecks package/racine passent.
- [ ] Aucun fichier hors périmètre n’est modifié, hormis le statut du plan.

## Conditions STOP

Arrêter et remonter le problème si :

- le Redis déployé interdit `EVAL` ou utilise un mode cluster qui exige une
  convention de key tags différente ;
- la réponse Bun à `EVAL` n’est pas convertible de façon fiable en nombre ;
- un consommateur souhaite renouveler la TTL à chaque hit : c’est une fenêtre
  glissante, donc une sémantique différente à décider explicitement ;
- un compteur direct avec TTL existe hors périmètre et ne peut pas adopter la
  primitive sans modifier sa politique ;
- un test de limite change de seuil ou de fallback pour passer ;
- une vérification échoue deux fois après correction raisonnable.

## Notes de maintenance

- Toute paire logique « incrémenter et expirer lors de la création » doit passer
  par cette primitive, jamais par deux commandes dans un nouveau module.
- La TTL n’est pas renouvelée : ce sont des fenêtres fixes. Un sliding window
  requerrait un autre nom, d’autres tests et une décision de produit.
- En review, vérifier que le script utilise `KEYS`/`ARGV` et non une interpolation
  de données dans Lua.
- Garder `incr` brut seulement pour les générations monotones sans durée de vie.
