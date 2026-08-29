# Plan 016 : Borner la rétention et la projection publique des trajets partagés

> **Instructions d’exécution** : suivre ce plan dans l’ordre. Exécuter chaque
> vérification et confirmer son résultat avant de continuer. Si une condition
> de la section « STOP » se produit, arrêter et remonter le problème sans
> improviser. À la fin, passer le statut de ce plan à `DONE` dans
> `plans/README.md`, sauf si un reviewer maintient lui-même l’index.
>
> **Vérification de dérive (à lancer en premier)** :
> `git diff --stat a58e6a12..HEAD -- packages/contract/src/public/journey-shares.ts packages/contract/src/public/journey-shares.test.ts packages/contract/src/public/index.ts apps/api/src/public/journey-shares/projection.ts apps/api/src/public/journey-shares/projection.test.ts apps/api/src/public/journey-shares/router.ts apps/api/src/routers/journey-shares/retention.ts apps/api/src/routers/journey-shares/retention.test.ts apps/api/src/index.ts apps/marketing/src/lib/journey-share.ts 'apps/marketing/src/app/trip/[token]/page.client.tsx'`
> Si un fichier du périmètre a changé depuis la rédaction du plan, comparer le
> code courant aux extraits ci-dessous. En cas de divergence structurelle,
> traiter cela comme une condition STOP.

## Statut

- **Priorité** : P1
- **Effort** : M
- **Risque** : MED — la projection nourrit une page publique existante et la purge change la durée de diagnostic des liens expirés
- **Dépend de** : aucun autre plan
- **Catégorie** : sécurité / confidentialité
- **Planifié au commit** : `a58e6a12`, 2026-08-29

## Pourquoi

Un lien expire fonctionnellement après 30 jours, mais sa ligne JSONB — noms,
horaires, géométries et coordonnées — n’est jamais supprimée. De plus, la route
`/public` renvoie aujourd’hui `share.snapshot` en bloc et le site le valide avec
le schéma privé de l’app. Tout futur champ ajouté au trajet iOS devient ainsi
public sans décision, exactement ce qu’ADR-0003 interdit.

La cible supprime par lots bornés les partages expirés ou révoqués après une
grâce de sept jours, et publie une forme indépendante limitée aux champs que la
page `/trip/[token]` rend réellement. Les coordonnées et géométries restent
présentes parce qu’elles sont l’objet du partage volontaire et dessinent la
carte ; les annotations privées, données de quai, reports et futurs champs sont
exclus par allowlist.

## État actuel

### Fichiers et responsabilités

- `packages/contract/src/journey-shares/schema.ts` — contrat privé iOS et validation des snapshots stockés.
- `packages/contract/src/public/lines.ts` — précédent d’un schéma site indépendant du contrat privé.
- `apps/api/src/public/lines/projection.ts` — précédent d’une projection champ par champ.
- `apps/api/src/public/journey-shares/router.ts` — route site qui transmet actuellement le snapshot privé.
- `apps/api/src/routers/journey-shares/service.ts` — valide expiration/révocation mais ne supprime rien.
- `packages/db/src/schema.ts:1197-1220` — table, index d’expiration et colonne de révocation existants.
- `apps/api/src/reports/runtime.ts` — précédent de purge horaire élue et bornée.
- `apps/marketing/src/lib/journey-share.ts` et `app/trip/[token]/page.client.tsx` — valident et rendent la réponse publique.

### Extraits à reconnaître

`apps/api/src/public/journey-shares/router.ts:30-40` transmet le contrat privé
en bloc :

```ts
try {
  const share = await getJourneyShare(parsed.data);
  c.header(
    "Cache-Control",
    "public, max-age=60, s-maxage=60, stale-while-revalidate=300",
  );
  return c.json({
    snapshot: share.snapshot,
    createdAt: share.createdAt,
    expiresAt: share.expiresAt,
  });
```

`packages/contract/src/journey-shares/schema.ts:10-16` attache directement le
trajet privé :

```ts
export const journeyShareSnapshotSchema = z.object({
  schemaVersion: z.literal(1),
  journey: journeySchema,
  generatedAt: z.iso.datetime({ offset: true }),
  locale: z.string().min(2).max(32),
  timeZone: z.string().min(1).max(64),
});
```

`apps/marketing/src/lib/journey-share.ts:1-4` confirme que le navigateur parse
ce même type privé :

```ts
import {
  journeyShareResponseSchema,
  type JourneyShareResponse,
} from "@via/contract";
```

`apps/api/src/routers/journey-shares/service.ts:106-123` rend les liens inactifs
sans effacer la ligne :

```ts
export async function getJourneyShare(
  token: string,
  now = new Date(),
): Promise<JourneyShareResponse> {
  const rows = await db
    .select()
    .from(journeyShares)
    .where(eq(journeyShares.tokenHash, tokenHash(token)))
    .limit(1);
  const row = rows[0];

  if (!row) throw new JourneyShareLookupError("not_found");
  if (row.revokedAt) throw new JourneyShareLookupError("revoked");
  if (row.expiresAt.getTime() <= now.getTime()) {
    throw new JourneyShareLookupError("expired");
  }

  return shareResponse(row);
}
```

La table possède déjà les index/champs nécessaires
(`packages/db/src/schema.ts:1206-1220`) :

```ts
export const journeyShares = pgTable(
  "journey_shares",
  {
    tokenHash: text("token_hash").primaryKey(),
    idempotencyKey: text("idempotency_key").notNull().unique(),
    ownerUserId: text("owner_user_id").references(() => users.id, {
      onDelete: "set null",
    }),
    snapshot: jsonb("snapshot").$type<Record<string, unknown>>().notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    revokedAt: timestamp("revoked_at", { withTimezone: true }),
  },
  (table) => [
    index("journey_shares_expires_idx").on(table.expiresAt),
    index("journey_shares_owner_idx").on(table.ownerUserId),
  ],
);
```

ADR-0003:26-28 est une contrainte, pas une suggestion :

> Règle qui rend ces mounts sûrs : **chaque route `/public` est une projection écrite à la main** (`apps/api/src/public/lines/projection.ts`), jamais une réponse du contrat transmise telle quelle.
>
> La conséquence à tenir : ajouter une procédure au contrat ne doit jamais suffire à la rendre publique.

Le précédent à copier est `apps/api/src/public/lines/projection.ts:19-31`, qui
reconstruit chaque objet et chaque champ optionnel au lieu de spreader la réponse
privée :

```ts
export function toPublicLineStatuses(
  response: LineStatusesResponse,
): PublicLineStatuses {
  return {
    source: response.source,
    ...(response.fetchedAt === undefined
      ? {}
      : { fetchedAt: response.fetchedAt }),
    lines: response.lines.map((line) => ({
      id: line.route.id,
      mode: line.route.mode,
      shortName: line.route.shortName,
      condition: line.condition,
      activeCount: line.activeCount,
      ...(line.summary === undefined ? {} : { summary: line.summary }),
      ...(line.upcoming === undefined ? {} : { upcoming: line.upcoming }),
    })),
  };
}
```

## Commandes utiles

| But                  | Commande                                                                                                               | Résultat attendu                                  |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| Tests contrat public | `bun test packages/contract/src/public/journey-shares.test.ts`                                                         | tous passent                                      |
| Tests API ciblés     | `bun test apps/api/src/public/journey-shares/projection.test.ts apps/api/src/routers/journey-shares/retention.test.ts` | tous passent                                      |
| Tests packages       | `bun run --filter=@via/contract test && bun run --filter=@via/api test && bun run --filter=@via/marketing test`        | exit 0                                            |
| Typecheck            | `bun run typecheck`                                                                                                    | 6 tâches réussies                                 |
| Build marketing      | `bun run --filter=@via/marketing build`                                                                                | build Next réussi, route `/trip/[token]` présente |

## Périmètre

### Fichiers autorisés

- `packages/contract/src/public/journey-shares.ts` (nouveau)
- `packages/contract/src/public/journey-shares.test.ts` (nouveau)
- `packages/contract/src/public/index.ts`
- `apps/api/src/public/journey-shares/projection.ts` (nouveau)
- `apps/api/src/public/journey-shares/projection.test.ts` (nouveau)
- `apps/api/src/public/journey-shares/router.ts`
- `apps/api/src/routers/journey-shares/retention.ts` (nouveau)
- `apps/api/src/routers/journey-shares/retention.test.ts` (nouveau)
- `apps/api/src/index.ts`
- `apps/marketing/src/lib/journey-share.ts`
- `apps/marketing/src/app/trip/[token]/page.client.tsx`
- `plans/README.md` (statut uniquement à la fin)

### Hors périmètre

- Le contrat privé `packages/contract/src/journey-shares/`, la création, le TTL
  fonctionnel de 30 jours et la génération des tokens.
- Le modèle DB et les migrations : l’index `expires_at` existe déjà.
- Une UI ou procédure pour lister/révoquer ses partages ; c’est une évolution
  produit distincte.
- La suppression de compte et la politique `ownerUserId SET NULL`.
- Le rendu, le design, MapLibre et les interactions de la page partagée.
- La suppression des coordonnées/géométries de la projection : sans elles, la
  fonctionnalité de carte n’existe plus.
- Les caches CDN/Next au-delà de leur TTL actuelle de 60 secondes.

## Git

- Branche recommandée : `codex/016-journey-share-privacy-lifecycle`.
- Commit recommandé : `fix(sharing): bound public journey data lifecycle`.
- Ne pas pousser ni ouvrir de PR sans demande explicite.

## Étapes

### 1. Déclarer un contrat public indépendant et minimal

Créer `packages/contract/src/public/journey-shares.ts` sur le modèle de
`public/lines.ts`, avec des `z.object` explicites qui n’importent ni
`journeySchema`, ni `journeyShareResponseSchema`, ni leurs `.pick()`/`.extend()`.
Déclarer et exporter les types inférés correspondants. Utiliser des objets Zod
stricts à chaque niveau (`z.strictObject` ou l’équivalent Zod 4) : un champ
inconnu doit faire échouer la validation publique, pas être silencieusement
retiré après avoir déjà traversé le réseau.

La réponse publique autorise exactement :

- réponse : `snapshot`, `expiresAt` ;
- snapshot : `schemaVersion`, `generatedAt`, `locale`, `timeZone`, `journey` ;
- journey : `durationSeconds`, `walkingDurationSeconds`, `transferCount`,
  `departureAt`, `arrivalAt`, `status`, `warnings`, `sections` ;
- section : `id?`, `type`, `durationSeconds`, `from`, `to`, `departureAt?`,
  `arrivalAt?`, `geometry`, `route?`, `direction?` ;
- point `from`/`to` et géométrie : latitude/longitude ;
- route : `shortName`, `longName`, `color`, `textColor`.

Ne pas publier `createdAt`, identifiant/qualifier du journey, tarif,
accessibilité, affluence, signalements, stops intermédiaires, horaires planifiés,
quai, service ID, statut de départ, placement voiture ou sortie. Les enums
publics `status` et `type` sont écrits explicitement afin qu’un ajout privé
provoque une décision publique, pas une propagation automatique.

Exporter schémas et types depuis `public/index.ts`. Dans le test, construire une
réponse publique minimale valide et vérifier le rejet des champs manquants et
des valeurs d’enum inconnues. Ajouter aussi un objet enrichi de sentinelles
privées et vérifier que le schéma strict le rejette. Le résultat de la
projection de l’étape suivante doit, lui, être accepté parce que ces champs
n’ont jamais été émis.

**Vérifier** : test contrat public et typecheck contract → code 0.

### 2. Construire la projection champ par champ

Créer `apps/api/src/public/journey-shares/projection.ts` avec
`toPublicJourneyShare(response: JourneyShareResponse): PublicJourneyShareResponse`.
Reconstruire chaque niveau et chaque collection avec une propriété nommée ; ne
jamais utiliser `{ ...response }`, `{ ...snapshot }`, `{ ...journey }`,
`{ ...section }`, ni retourner un sous-objet privé directement. Les coordonnées
et routes sont elles aussi reconstruites champ par champ.

Avant de retourner, parser l’objet reconstruit avec
`publicJourneyShareResponseSchema`. Le schéma strict devient ainsi la dernière
barrière côté serveur : même un futur spread accidentel échoue avant
`c.json(...)`, au lieu d’envoyer puis de faire rejeter le champ par le site.

Dans `projection.test.ts`, créer un `JourneyShareResponse` privé qui remplit les
champs exclus avec des sentinelles uniques : `fare`, `accessibility`, `peak`,
reports, `stops`, `platform`, `serviceId`, `boardingPosition` et `exit`. Vérifier
la forme publique utile à la page, puis exiger qu’aucune sentinelle ni clé privée
n’apparaisse dans `JSON.stringify(projected)`. Enfin parser le résultat avec le
nouveau schéma public.

**Vérifier** : test projection → tous les cas passent.

### 3. Basculer la route et le site sur le contrat public

Dans `public/journey-shares/router.ts`, appeler `toPublicJourneyShare(share)` et
retourner uniquement son résultat. Conserver validation du token, codes 404/410/
503, messages et `Cache-Control` actuels.

Dans `apps/marketing/src/lib/journey-share.ts`, importer schéma et type depuis
`@via/contract/public`, puis parser la réponse avec le schéma public. Renommer le
type de query interne si nécessaire, mais ne changer ni retry, ni cache, ni
codes d’erreur. Dans `page.client.tsx`, remplacer `JourneySection` et
`JourneyShareResponse` privés par les types publics ; la liste de champs ci-dessus
doit suffire au rendu actuel. Ne modifier aucun JSX ou style pour satisfaire le
typecheck : si un champ omis est réellement rendu, traiter cela comme une
condition STOP et décider s’il est légitime avant de l’ajouter.

**Vérifier** :

```bash
rg -n "snapshot: share\.snapshot" apps/api/src/public/journey-shares/router.ts
bun run --filter=@via/marketing typecheck
bun run --filter=@via/marketing build
```

Résultats attendus : aucune occurrence du forwarding, typecheck 0 et build Next
réussi avec `/trip/[token]`.

### 4. Ajouter une purge horaire bornée avec grâce

Créer `routers/journey-shares/retention.ts` sur le modèle de
`reports/runtime.ts`. Constantes : exécution horaire, grâce de sept jours après
expiration ou révocation, lot maximum de 500. Exporter une fonction pure de
cutoff et une fonction de purge injectable/testable.

La requête PostgreSQL doit supprimer au plus 500 lignes dont :

- `expires_at` est antérieur ou égal au cutoff ; ou
- `revoked_at` est non null et antérieur ou égal au cutoff.

Sélectionner d’abord les candidats avec un ordre déterministe par date de fin
puis `token_hash`, les supprimer dans une seule commande et retourner le nombre
réel. Réutiliser `jobDb`, `sql` et `timestamptz` comme la purge des signalements.
Ne lire ni désérialiser le JSONB.

Élire un seul runtime par cycle avec `SET NX EX`, lancer une passe au démarrage,
puis chaque heure. En test, ne démarrer aucun timer. Une panne se journalise avec
un libellé statique et sera retentée au cycle suivant ; elle ne doit pas arrêter
l’API.

Dans `retention.test.ts`, vérifier : cutoff exact à sept jours, lot transmis à
500, un seul appel pour une élection gagnée, aucun pour une élection perdue, et
propagation contrôlée d’une erreur repository sans timer réel.

**Vérifier** : test retention ciblé → tous les cas passent.

### 5. Démarrer le runtime et exécuter la non-régression

Dans `apps/api/src/index.ts`, appeler `startJourneyShareRetentionRuntime()` à
côté de `startReportRuntime()` et du runtime notifications. Ne modifier ni le
port ni `app.fetch`.

**Vérifier** :

```bash
bun run --filter=@via/contract test
bun run --filter=@via/api test
bun run --filter=@via/marketing test
bun run typecheck
bun run --filter=@via/marketing build
```

Toutes les commandes doivent sortir avec le code 0.

## Plan de test

- Schéma public autonome : fixture valide, champs obligatoires, enums fermés et
  rejet strict des sentinelles privées.
- Projection : forme utile complète et absence sérialisée de chaque catégorie
  privée connue.
- Site : typecheck et build prouvent que l’allowlist couvre le rendu réel.
- Rétention : cutoff sept jours, batch 500, élection gagnée/perdue et panne.
- Suite API : codes expired/revoked/not-found inchangés avant purge.
- Aucun test ne requiert un token, une URL de base ou une base de production.

## Critères de fin

- [ ] `/public/journey-shares` retourne un type de `@via/contract/public`, jamais le snapshot privé brut.
- [ ] Le schéma public n’importe ni n’étend les schémas privés de journey/share.
- [ ] Chaque niveau est projeté champ par champ sans spread d’objet privé.
- [ ] La page partagée affiche toujours carte, étapes, horaires, warnings et expiration.
- [ ] Les champs privés listés dans ce plan sont absents de la sérialisation publique.
- [ ] Les lignes expirées/révoquées depuis sept jours sont supprimées par lots de 500 maximum.
- [ ] La purge démarre avec l’API, ne tourne pas pendant les tests et retente après panne.
- [ ] Tests contract/API/marketing, typecheck global et build Next passent.
- [ ] Aucune migration ni fichier hors périmètre n’est modifié.

## Conditions STOP

Arrêter et remonter le problème si :

- la page rend réellement un champ privé exclu : expliquer son besoin avant de
  l’ajouter à l’allowlist ;
- le produit exige un code 410 fiable pendant plus de sept jours après
  expiration/révocation ;
- la table ou l’index d’expiration a changé depuis le plan ;
- la purge nécessite de charger le JSONB ou de supprimer plus de 500 lignes par cycle ;
- le contrat public ne peut pas rester dans l’entrypoint séparé
  `@via/contract/public` ;
- une future UI de révocation ou de listing devient nécessaire pour rendre ce
  plan fonctionnel : la sortir dans un plan produit distinct ;
- une vérification échoue deux fois après correction raisonnable.

## Notes de maintenance

- Ajouter un champ au trajet privé ne le rend jamais public. Il faut modifier
  séparément schéma public, projection, test de sentinelle et site.
- Les coordonnées sont publiques pour toute personne possédant le token pendant
  sa durée de vie ; le token reste donc une capability à traiter comme un secret
  partageable.
- La grâce de sept jours permet encore un diagnostic `expired`/`revoked`, puis la
  confidentialité de rétention prime et la réponse devient `not_found`.
- Une future gestion « mes liens partagés » doit réutiliser `ownerUserId` et
  `revokedAt`, mais rester sur une route authentifiée hors de `/public`.
- En review, rechercher les spreads et les imports depuis `@via/contract` dans
  toute la chaîne publique ; ce sont les deux régressions architecturales les
  plus probables.
