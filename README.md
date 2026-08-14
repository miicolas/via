# via

Turborepo monorepo: an Expo app, a Hono API, and a PostGIS-backed Postgres.

```
apps/
  mobile/     Expo SDK 57 app (expo-router), was the repo root
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
ln -s ../../.env apps/mobile/.env   # Expo only reads .env from its own project root
bun run db:up                 # Postgres 18 + PostGIS 3.6 in Docker
bun run db:migrate
bun run dev                   # api + mobile via turbo
```

Run one side only: `bun run dev:api` / `bun run dev:mobile`.
Native build: `bun run ios`.

The symlink matters because `EXPO_PUBLIC_API_URL` is inlined at bundle time: without
it, a bare `expo start` (instead of the `bun run` scripts, which pass `--env-file`)
silently falls back to `http://localhost:3000` and the map fails to load.

## Scripts

| Script | What it does |
| --- | --- |
| `bun run dev` | every package's `dev` task, in parallel |
| `bun run build` | `expo export` for mobile |
| `bun run typecheck` | `tsc --noEmit` across all packages |
| `bun run test` | `bun test` across all packages |
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

`apps/api` exports its route table as `AppType`, and `apps/mobile/src/lib/api.ts`
builds a typed client from it:

`packages/contract` declares the paths, methods and payloads. The API implements
it, the app calls it, and neither depends on the other:

```ts
import { api } from '@/lib/api';

const { routes, stations } = await api.network.map();   // fully typed
```

Point `EXPO_PUBLIC_API_URL` at your machine's LAN IP when running on a physical
device — `localhost` only resolves on the iOS simulator.

`bun run typecheck` at the root is what proves both sides still agree: adding a
procedure to the contract without implementing it, or returning the wrong shape
from a mapper, fails to compile.

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
| `/api` | REST at the contract's paths, described by `/api/openapi.json` | third parties, `check:transit-alignment` |
| `/rpc` | oRPC | the app, through `createORPCClient` |

The app's client is configured to issue `GET`, so the network map stays
cacheable by the platform HTTP cache and is gzip-compressed to roughly 800 kB;
the default `POST` would silently give that up. Metro and RER carry normalized
polylines. Bus routes carry their stops and metadata but no geometry, keeping
the surface network from covering the map in strokes.

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

## Not wired up yet

`apps/mobile` still has an `expo lint` script but ESLint isn't installed, so
there's no `lint` task in `turbo.json`. Run `bunx expo lint` inside
`apps/mobile` once to let Expo scaffold it, then add the task back.
