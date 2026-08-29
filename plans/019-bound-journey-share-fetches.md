# Plan 019: Borner chaque lecture de trajet partagé et conserver un état indisponible

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- apps/marketing/src/lib/api.ts apps/marketing/src/lib/journey-share.ts apps/marketing/src/lib/journey-share.test.ts 'apps/marketing/src/app/trip/[token]/page.tsx'`
> Si le chargement du partage, sa stratégie React Query ou le fallback des
> métadonnées a changé, comparer le code courant aux extraits ci-dessous avant
> de poursuivre. Ce plan s’exécute **après**
> `plans/016-borner-cycle-vie-partages-trajets.md` : son entrypoint
> `@via/contract/public`, son schéma et ses types publics sont la précondition à
> conserver. Une nouvelle politique de timeout globale, l’absence de cette
> précondition ou un retour au contrat privé est une condition STOP jusqu’à
> réconciliation.

## Statut

- **Priorité** : P2
- **Effort** : S
- **Risque** : LOW — ajout d’annulation et tests, sans changement du contrat public de 016 ni de l’UI d’erreur
- **Dépend de** : `plans/016-borner-cycle-vie-partages-trajets.md`
- **Catégorie** : bug / perf
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Le rendu serveur des métadonnées et de la page `/trip/[token]`, puis les
rafraîchissements navigateur, appellent tous `fetchJourneyShare`. Contrairement
aux autres lectures marketing, ce fetch n’a aucun signal de délai : une API qui
accepte la connexion mais ne répond plus peut bloquer le rendu, l’aperçu social
et des ressources serveur jusqu’au timeout de plateforme. La cible réutilise la
politique locale de trois secondes, propage aussi l’annulation de React Query et
continue de dégrader vers l’état « indisponible » déjà dessiné, sans exposer la
clé serveur ni changer les erreurs métier expiré/révoqué/introuvable.

Le plan 016 remplace parallèlement le schéma privé par un schéma public strict.
Le présent plan part de cet état post-016 : il borne le transport sans élargir le
payload, sans restaurer un import depuis `@via/contract` et sans refaire la
projection de confidentialité.

## État actuel

### Fichiers et responsabilités

- `apps/marketing/src/lib/api.ts` — centralise origine, clé serveur et timeout de trois secondes pour les lectures JSON secondaires.
- `packages/contract/src/public/journey-shares.ts` — après le plan 016, possède le schéma et le type publics stricts que le site doit continuer d’utiliser.
- `apps/marketing/src/lib/journey-share.ts` — fonction de fetch commune au serveur et au navigateur, validation Zod publique et options React Query.
- `apps/marketing/src/app/trip/[token]/page.tsx` — appelle la même fonction pour `generateMetadata` et `prefetchQuery`.
- `apps/marketing/src/app/trip/[token]/page.client.tsx` — mappe déjà une erreur React Query vers `JourneyShareErrorState(code: "unavailable")` et expose Réessayer.

### Extraits à reconnaître avant modification

`apps/marketing/src/lib/api.ts:39-61` établit déjà la politique locale :

```ts
const TIMEOUT_MS = 3_000;

export async function readJson<T>(
  path: string,
  revalidate: number,
): Promise<T | null> {
  // ...
  const response = await fetch(`${origin}${path}`, {
    headers: serverHeaders(),
    signal: AbortSignal.timeout(TIMEOUT_MS),
    next: { revalidate },
  });
  // une panne retourne null
}
```

`apps/marketing/src/lib/journey-share.ts:46-69` ne fournit aucun signal :

```ts
export async function fetchJourneyShare(
  token: string,
): Promise<JourneyShareQueryData> {
  // ...
  response = await fetch(
    `${origin}/public/journey-shares/${encodeURIComponent(token)}`,
    init,
  );
}
```

L’extrait ci-dessus décrit le commit de planification. Avant d’exécuter 019, le
plan 016 doit avoir remplacé l’import privé de tête par cette forme publique (à
nommage équivalent si 016 l’a fait évoluer explicitement) :

```ts
import {
  publicJourneyShareResponseSchema,
  type PublicJourneyShareResponse,
} from "@via/contract/public";
```

`JourneyShareQueryData` et `journeyEndpoints` doivent alors référencer
`PublicJourneyShareResponse`. Cette surface publique est un invariant de 019,
pas un fichier à modifier dans ce plan.

`apps/marketing/src/lib/journey-share.ts:85-92` ignore aussi le signal donné par
TanStack Query :

```ts
return {
  queryKey: journeyShareQueryKey(token),
  queryFn: () => fetchJourneyShare(token),
  staleTime: 60_000,
  refetchOnWindowFocus: false,
  retry: 1,
} as const;
```

`apps/marketing/src/app/trip/[token]/page.tsx:31-59` attrape déjà toute erreur de
chargement dans `generateMetadata` et retourne un titre/texte génériques. Aux
lignes 75-81, `prefetchQuery` tolère aussi l’échec et laisse le client réessayer.

`apps/marketing/src/app/trip/[token]/page.client.tsx:72-89` rend déjà :

```tsx
if (query.isError) {
  return (
    <JourneyShareErrorState
      code="unavailable"
      onRetry={() => void query.refetch()}
    />
  );
}
```

### Contraintes à conserver

- La clé `VIA_SITE_CLIENT_KEY` ne quitte jamais `serverHeaders()` et n’est jamais
  transmise dans le navigateur.
- Serveur : garder `next: { revalidate: 60 }`. Navigateur : garder
  `cache: "no-store"`.
- Les codes métier d’une réponse HTTP (`not_found`, `expired`, `revoked`,
  `unavailable`) restent des données et ne deviennent pas des exceptions.
- Les pannes réseau, timeouts et réponses invalides restent des exceptions
  génériques ; React Query applique son unique retry puis montre l’état
  indisponible. Ne pas inclure l’URL ou le token dans le message d’erreur.
- Une annulation issue du signal appelant est différente d’une indisponibilité :
  laisser remonter l’erreur/raison d’annulation originale sans l’envelopper dans
  `Journey share request failed.`. Cela inclut un signal déjà aborté à l’entrée,
  afin que TanStack Query conserve sa sémantique de cancellation et ne lance pas
  un retry réseau comme pour une panne.
- Trois secondes est la politique déjà documentée du site. Ne pas inventer une
  durée différente sans mesure/ADR.
- Le signal de timeout doit être combiné avec le signal appelant, pas le
  remplacer : quitter la page doit annuler le fetch immédiatement.
- Conserver l’import depuis `@via/contract/public`, le parsing avec
  `publicJourneyShareResponseSchema` et le type `PublicJourneyShareResponse`
  introduits par 016. Ne pas importer un schéma/type de partage privé pour
  simplifier les tests.

## Commandes utiles

| But             | Commande                                                | Résultat attendu     |
| --------------- | ------------------------------------------------------- | -------------------- |
| Tests ciblés    | `bun test apps/marketing/src/lib/journey-share.test.ts` | tous les cas passent |
| Tests marketing | `bun run --filter=@via/marketing test`                  | tous passent         |
| Typecheck       | `bun run --filter=@via/marketing typecheck`             | exit 0               |
| Lint            | `bun run --filter=@via/marketing lint`                  | exit 0               |
| Build           | `bun run --filter=@via/marketing build`                 | exit 0               |

## Périmètre

### Fichiers autorisés

- `apps/marketing/src/lib/api.ts`
- `apps/marketing/src/lib/journey-share.ts`
- `apps/marketing/src/lib/journey-share.test.ts` (nouveau)
- `apps/marketing/src/app/trip/[token]/page.tsx` uniquement si l’option de retry serveur doit être rendue explicite
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- `apps/marketing/src/app/trip/[token]/page.client.tsx` — après 016, il consomme déjà le type public ; son état indisponible et son bouton retry existent déjà.
- `packages/contract/src/public/journey-shares.ts`, `packages/contract/src/public/index.ts`, le contrat privé `@via/contract` et les endpoints de partage côté API : 016 en est propriétaire.
- Le TTL de 60 secondes, le cache React, la durée de vie du lien et les codes métier.
- Le vote de ville `submitCityVote`, qui est une écriture distincte et ne bloque pas le rendu SSR.
- Les textes, la carte et la mise en page du trajet partagé.
- Une bibliothèque de retry/timeout supplémentaire.

## Git

- Branche recommandée : `codex/019-bound-journey-share-fetches`.
- Commits logiques, par exemple
  `fix(marketing): bound journey share requests`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 0. Vérifier et figer la précondition du plan 016

Ne pas exécuter 016 et 019 en parallèle : les deux modifient
`apps/marketing/src/lib/journey-share.ts`. Vérifier que 016 est terminé et que
le site parse la réponse avec l’entrypoint public, sans import résiduel du schéma
privé :

**Vérifier** :

```bash
test -f packages/contract/src/public/journey-shares.ts
rg -n 'publicJourneyShareResponseSchema|PublicJourneyShareResponse|from "@via/contract/public"' packages/contract/src/public/journey-shares.ts packages/contract/src/public/index.ts apps/marketing/src/lib/journey-share.ts 'apps/marketing/src/app/trip/[token]/page.client.tsx'
rg -n 'journeyShareResponseSchema|JourneyShareResponse.*from "@via/contract"' apps/marketing/src/lib/journey-share.ts 'apps/marketing/src/app/trip/[token]/page.client.tsx'
```

Résultats attendus : les exports/imports publics apparaissent ; la dernière
commande ne trouve aucun import/usage privé dans ces deux consommateurs. Lire
ensuite le diff de 016 et conserver ses noms publics effectifs. Si le fichier,
l’export ou le parsing public manque, STOP : terminer/réconcilier 016 avant de
toucher au transport.

### 1. Extraire la politique de signal borné sans dupliquer la durée

Dans `lib/api.ts`, renommer/exporter la constante de trois secondes avec un nom
explicite, par exemple `API_REQUEST_TIMEOUT_MS`, puis exporter une fonction pure :

```ts
export function boundedApiSignal(
  upstream?: AbortSignal,
  timeoutMs: number = API_REQUEST_TIMEOUT_MS,
): AbortSignal;
```

La fonction crée `AbortSignal.timeout(timeoutMs)`. Si un signal appelant existe,
elle renvoie un signal qui s’annule dès que l’un des deux s’annule
(`AbortSignal.any`). Sans signal appelant, elle renvoie simplement le timeout.
Valider que `timeoutMs` est fini et strictement positif si le type public permet
une valeur arbitraire ; une valeur de test courte reste autorisée.

Modifier `readJson` pour appeler ce helper sans changer son comportement
`null`-on-failure. Ainsi, la durée reste écrite une seule fois et les tests du
partage peuvent injecter une durée courte sans attendre trois secondes.

**Vérifier** : `bun run --filter=@via/marketing typecheck` → exit 0.

### 2. Rendre `fetchJourneyShare` annulable et testable

Ajouter un second argument optionnel étroit :

```ts
type FetchJourneyShareOptions = {
  readonly signal?: AbortSignal;
  readonly timeoutMs?: number;
  readonly fetcher?: typeof fetch;
};
```

Respecter `exactOptionalPropertyTypes` : ne pas construire un objet contenant
`signal: undefined`. Les valeurs par défaut sont le fetch global et
`API_REQUEST_TIMEOUT_MS`.

Dans le `RequestInit` commun aux branches serveur/navigateur, ajouter :

```ts
signal: boundedApiSignal(options.signal, options.timeoutMs),
```

Utiliser `options.fetcher ?? fetch` pour le call. Avant le call, si
`options.signal` est déjà aborté, lever sa `reason` (ou une `DOMException`
`AbortError` si la plateforme n’en fournit pas) sans appeler le réseau. Dans le
`catch`, si ce même signal appelant est maintenant aborté, relancer l’erreur
d’annulation reçue **inchangée**. Ne convertir en
`new Error("Journey share request failed.")` que le timeout interne ou une panne
réseau, sans token, URL, clé ou cause sérialisée. Le serveur continuera à
attraper les indisponibilités pour ses métadonnées ; TanStack peut, lui,
reconnaître l’annulation appelante au lieu de la traiter comme une panne à
réessayer.

Ne toucher ni à l’import `@via/contract/public`, ni au
`publicJourneyShareResponseSchema.safeParse`, ni au type public établi par 016.

**Vérifier** : `bun run --filter=@via/marketing typecheck` → exit 0.

### 3. Propager l’annulation TanStack Query

Modifier `journeyShareQueryOptions` pour consommer le contexte de `queryFn` :

```ts
queryFn: ({ signal }) => fetchJourneyShare(token, { signal }),
```

Conserver `retry: 1`, `staleTime` et `refetchOnWindowFocus`. Le `loadShare =
cache(fetchJourneyShare)` serveur continue à appeler la fonction avec le seul
token et reçoit automatiquement le timeout.

Pour `prefetchQuery` côté serveur, conserver le `queryFn` basé sur `loadShare`
afin que métadonnées et page partagent la même Promise. Si la version de TanStack
relance deux appels bornés côté serveur malgré ce cache et rend la latence
maximale inacceptable, il est permis d’ajouter `retry: false` **uniquement** à
l’override serveur dans `page.tsx`; le navigateur garde son unique retry.

**Vérifier** :

```bash
rg -n 'queryFn: \(\{ signal \}\).*fetchJourneyShare' apps/marketing/src/lib/journey-share.ts
```

Résultat attendu : une occurrence.

### 4. Tester timeout, annulation et erreurs sans attendre le temps réel

Créer `lib/journey-share.test.ts` avec `bun:test`. Utiliser l’option `fetcher`
plutôt que remplacer `globalThis.fetch`. Sauvegarder/restaurer toute variable
`NEXT_PUBLIC_API_URL` modifiée par le test dans `beforeEach/afterEach` ou un
`try/finally`.

Importer `publicJourneyShareResponseSchema` et
`PublicJourneyShareResponse` depuis `@via/contract/public`. Construire la
fixture de succès avec `satisfies PublicJourneyShareResponse` et la valider avec
le schéma public ; réutiliser la fixture minimale de 016 si un helper de test
public existe. Elle ne doit notamment pas réintroduire `createdAt` ou un champ
privé omis par la projection de 016.

Écrire un faux fetch qui :

- capture `RequestInit.signal` ;
- ne résout jamais spontanément ;
- rejette dès l’événement `abort`.

Couvrir :

1. avec `timeoutMs: 10`, la Promise rejette avec le message générique dans une
   borne large et non flaky (par exemple moins de 500 ms) ;
2. un signal appelant **déjà aborté**, avec une raison `AbortError` sentinelle,
   fait rejeter avec la même instance/raison, jamais avec le message générique,
   et le faux fetch confirme qu’aucun réseau n’est démarré ;
3. un `AbortController` appelant annule pendant un timeout long : le faux fetch
   observe l’abort et l’erreur d’annulation ressort inchangée ;
4. une réponse HTTP de succès conforme à la fixture
   `PublicJourneyShareResponse` devient `kind = "ready"` après parsing par le
   schéma public ;
5. une réponse HTTP d’erreur avec code connu retourne le même
   `JourneyShareQueryData.kind = "error"`, sans être transformée en panne réseau ;
6. une réponse HTTP d’erreur au corps invalide retourne le code `unavailable` ;
7. `journeyShareQueryOptions` appelée avec un contexte dont le signal est déjà
   aborté transmet cette annulation et laisse remonter la même raison ;
8. la branche de requête serveur garde les headers de `serverHeaders` et
   `next.revalidate = 60` sans exposer de valeur de clé dans les attentes.

Ne pas attendre 3 000 ms dans la suite. Ne pas tester une valeur réelle de
secret ; seulement présence/absence d’un nom d’en-tête avec une valeur sentinelle
locale si nécessaire.

**Vérifier** : `bun test apps/marketing/src/lib/journey-share.test.ts` → tous les tests passent en moins d’une seconde environ.

### 5. Valider les deux chemins de rendu

Exécuter la suite et le build. Relire les deux fallbacks déjà présents :

- `generateMetadata` retourne la métadonnée générique quand le fetch borné rejette ;
- `JourneySharePageClient` rend `JourneyShareErrorState("unavailable")` après
  échec/retry et Réessayer déclenche une nouvelle requête elle aussi bornée.

Aucune modification UI n’est attendue. Si un test ciblé exige d’exporter une
fonction pure, l’export reste dans `lib/journey-share.ts`, pas dans le composant.

**Vérifier** :

```bash
bun run --filter=@via/marketing test
bun run --filter=@via/marketing typecheck
bun run --filter=@via/marketing lint
bun run --filter=@via/marketing build
```

Résultat attendu : quatre exits 0.

## Plan de test

- Nouveau `journey-share.test.ts` : timeout injecté, annulation appelante avant
  et pendant le fetch, propagation sans enveloppe du signal Query, succès typé
  par le contrat public, erreur HTTP connue/inconnue et options serveur.
- Le faux fetch doit respecter `AbortSignal`, sinon un test de timeout pourrait
  passer sans prouver que le réseau est réellement interrompu.
- Les tests ne lisent aucun secret et restaurent l’environnement.
- Suite marketing complète et build Next pour couvrir l’import du même helper
  dans les bundles serveur et client.
- Vérification manuelle facultative avec une URL API locale qui ne répond pas :
  les métadonnées et l’état indisponible doivent apparaître en temps borné, sans
  laisser une requête active après navigation.

## Critères de fin

- [ ] La durée de trois secondes n’est définie qu’une fois dans `lib/api.ts`.
- [ ] Toute lecture de trajet partagé possède un signal de timeout.
- [ ] Le signal TanStack Query est combiné au timeout et propagé jusqu’au fetch.
- [ ] Un signal appelant déjà aborté et une annulation en vol ressortent comme
      annulations originales, sans message générique ni nouvel appel réseau.
- [ ] Serveur et navigateur conservent respectivement revalidation et `no-store`.
- [ ] Les codes métier HTTP restent inchangés.
- [ ] Timeout/réseau deviennent une erreur générique puis l’état indisponible existant.
- [ ] Le parsing et les fixtures restent typés par
      `PublicJourneyShareResponse` depuis `@via/contract/public` ; aucun champ
      privé de 016 n’est restauré.
- [ ] Les huit cas ciblés passent sans attente de trois secondes.
- [ ] Tests, typecheck, lint et build marketing sortent 0.
- [ ] Aucun token, URL complète de partage ou valeur de clé n’est journalisé/testé.
- [ ] Aucun fichier hors périmètre n’est modifié, hormis le statut dans `plans/README.md`.

## Conditions STOP

Arrêter et remonter le problème si :

- le plan 016 n’est pas terminé, son schéma/type public n’est pas exporté depuis
  `@via/contract/public`, ou son import public a été remplacé par le contrat
  privé dans le site ;
- le payload public de 016 ne suffit plus au rendu et il faudrait l’élargir :
  réconcilier 016 et sa décision de confidentialité, pas contourner le schéma
  depuis ce plan ;
- la plateforme cible ou les types du projet ne supportent pas
  `AbortSignal.timeout`/`AbortSignal.any` et une alternative exige un polyfill
  global ;
- une nouvelle politique documentée fixe une durée différente pour les pages de
  partage ;
- le fetch est désormais effectué via un client généré qui possède sa propre
  annulation/stratégie de retry ;
- rendre l’erreur indisponible demande de modifier le contrat ou les codes côté API ;
- React cache ou TanStack Query lance des retries serveur non bornés qui ne
  peuvent pas être désactivés localement ;
- un test dépend d’un réseau réel ou d’une valeur de secret ;
- un test/build échoue deux fois après correction raisonnable ;
- un fichier hors périmètre doit être modifié.

## Notes de maintenance

- Tout nouveau helper de lecture serveur devrait réutiliser
  `boundedApiSignal`; ne pas réintroduire des constantes `3_000` par route.
- Un retry multiplie la borne de latence totale. Toute augmentation future de
  `retry` doit être évaluée avec le timeout, côté serveur comme navigateur.
- En review, vérifier que le signal Query n’est pas perdu dans une closure sans
  argument, que son `AbortError` n’est pas capturé comme indisponibilité et que
  le fetch injecté des tests n’est jamais utilisé en production.
- Le contrat public est possédé par le plan 016. Si son nom change, adapter les
  imports/tests de 019 au nouvel export public documenté sans réintroduire un
  import depuis l’entrypoint privé.
- La page de partage contient les coordonnées d’un trajet ; garder les messages
  d’erreur génériques évite aussi de faire remonter le token ou l’URL dans les
  logs de rendu.
