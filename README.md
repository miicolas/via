# via

Monorepo with a native SwiftUI iOS app, a Hono API, and PostGIS-backed Postgres.

```
apps/
  via/        SwiftUI iOS 26 app and generated OpenAPI client
  api/        Hono on Bun, serving an oRPC contract
  worker/     GTFS importer
packages/
  contract/   the API contract: paths, methods, zod payloads
  db/         Drizzle schema + migrations (PostGIS)
scripts/      one-off checks, typechecked like everything else
```

## Getting started

```bash
bun install
cp .env.example .env          # adjust ports if 5432/3000 are taken
bun run db:up                 # Postgres 18 + PostGIS 3.6 in Docker
bun run db:migrate
bun run dev:api
```

Open `apps/via/via.xcodeproj` in Xcode for development, or run `bun run ios` for a command-line simulator build. API base URLs live in `apps/via/Configuration/*.xcconfig`.

## Scripts

| Script | What it does |
| --- | --- |
| `bun run dev` / `dev:api` | starts the API in watch mode |
| `bun run ios` | builds the native app for an iOS simulator |
| `bun run typecheck` | `tsc --noEmit` across all packages |
| `bun run test` | `bun test` across all packages |
| `bun run generate:ios-api` | regenerates the OpenAPI document and Swift client |
| `bun run check:openapi` | verifies generated API artifacts are current |
| `bun run check:transit-alignment` | checks metro/RER stop alignment and that buses have no trace (needs the API running) |
| `bun run db:up` / `db:down` / `db:reset` | Docker Postgres + Redis lifecycle (`db:reset` drops both volumes) |
| `bun run db:generate` | diff the schema into a new SQL migration |
| `bun run db:migrate` | apply pending migrations |
| `bun run db:studio` | Drizzle Studio |
| `bun run gtfs:import <path>` | imports metro, RER A–E and all bus lines from an extracted IDFM GTFS feed |

## Database

`docker-compose.yml` runs `imresamu/postgis:18-3.6-alpine` and a local Redis 7
service. The official `postgis/postgis` images are amd64-only, this one is the
same upstream build published multi-arch so it runs natively on Apple Silicon.

The schema lives in `packages/db/src/schema.ts`. Geo columns use
`pointWgs84` from `src/columns.ts` rather than drizzle's built-in `geometry()`:
drizzle-orm 0.45 accepts an `srid` option but silently drops it, emitting
`geometry(point)` and inserting SRID-0 values. `pointWgs84` pins
`geometry(Point,4326)` in the DDL and wraps every insert in `ST_SetSRID`.

Because that hand-rolled type would confuse `drizzle-kit push` (which diffs
against the live database), the workflow here is `generate` → `migrate` only.

## API ↔ app

`packages/contract` declares the paths, methods and payloads. The API implements them and `bun run generate:ios-api` produces the OpenAPI document plus the Swift client consumed behind `LiveViaAPIClient`.

`bun run typecheck` proves the TypeScript contract and server agree. `bun run check:openapi` additionally proves that the versioned Swift-facing artifacts are current.

## Notifications APNs et Live Activities

Le flux APNs est complet de l’app au provider :

- l’app demande la permission, s’enregistre à chaque lancement et envoie le
  token APNs au compte courant ; le token n’est jamais persisté localement ;
- une Live Activity est démarrée avec `pushType: .token`, et ses rotations de
  token ainsi que le token `push-to-start` sont synchronisés vers l’API ;
- l’API conserve les tokens par installation/environnement, signe les requêtes
  avec la clé APNs et purge les tokens invalides retournés par Apple ;
- `notificationDelivery` fournit les opérations de notification, de mise à
  jour/fin de Live Activity (par activité ou par trajet) et de démarrage
  distant pour les jobs métier.
- Les rappels de trajet restent locaux (départ, correspondances, arrivée) et
  mémorisent une seule intention par installation ; les perturbations des
  lignes d’un trajet suivi passent par APNs et le monitor PRIM partagé.

Après `bun run db:migrate`, renseigner côté serveur `APNS_TEAM_ID`,
`APNS_KEY_ID`, `APNS_PRIVATE_KEY` et `APNS_BUNDLE_ID`. La clé privée reste
uniquement dans l’environnement de l’API ; les builds Debug/Staging utilisent
`sandbox`, et Release utilise `production`.

## API structure

One folder per theme under `apps/api/src/routers/`, mirroring the URL tree, so
`routers/network/` serves `/api/network`:

```
routers/network/
  router.ts               the procedures this theme exposes
  handlers/*.ts           one file per procedure: orchestration only
  queries.ts              drizzle + PostGIS, returns rows
  mappers.ts              rows -> contract payload. Pure: no db, unit-testable
```

Imports point downward only — `router` → `handlers` → `queries`/`mappers` →
`geo`/`orpc` — and nothing under `routers/` imports `app.ts`.

Adding an endpoint means a procedure in `packages/contract`, a file in
`handlers/`, and a line in `router.ts`. `implementer.router()` in
`routers/index.ts` is the assertion that nothing in the contract is left
unimplemented.

### Two transports, one router

Hono keeps the HTTP edge — logging, CORS, request ids, the error envelope — and
mounts oRPC twice over the same procedures:

| Mount | Protocol | Who calls it |
| --- | --- | --- |
| `/api` | REST at the contract's paths, described by `/api/openapi.json` | iOS app and third parties |
| `/rpc` | oRPC | internal typed integrations |

The iOS client uses cacheable `GET` operations through `URLSession`. Metro and RER carry normalized polylines. Bus routes carry their stops and metadata but no geometry, keeping the surface network from covering the map in strokes.

## Realtime departures

`/api/departures?stationId=…` answers the next departures per line and
destination, and says in `source` what the timestamps are worth: `realtime`
(PRIM), `theoretical` (the imported GTFS schedule), or `unavailable`.

PRIM's quota is the constraint the design is built around: an API token issued
after March 2024 gets **1 000 requests a day, 5 a second** — a single station
polled once a minute over a service day would spend it all. So:

- every PRIM call goes through the server, never the app;
- responses live in local Redis for ~120 s, behind a `SET NX` lock, so N
  riders looking at one station cost about one upstream call;
- a per-day counter (`prim:budget:*`, Paris calendar) is incremented *before*
  each call and refuses once the daily ceiling minus a 5 % reserve is reached;
- when consumption runs ahead of the hour's prorata, the cache TTL doubles then
  quadruples (`adaptive-ttl.ts`) instead of the quota simply running out;
- anything that fails — no key, Redis down, PRIM down, budget spent — falls
  through to the theoretical schedule, labelled as such in the app.

`REDIS_URL` points the API at the local container by default. Without
`API_KEY_PRISM_IDFM`, the endpoint still works but never returns `realtime`.

`scripts/spike-prim-mapping.ts` is the one-off that validates our GTFS ids map
onto the STIF refs PRIM expects (`STIF:StopArea:SP:{n}:`, `STIF:Line::{code}:`)
and saves a real payload as a parser fixture.
