# via

Turborepo monorepo: an Expo app, a Hono API, and a PostGIS-backed Postgres.

```
apps/
  mobile/   Expo SDK 57 app (expo-router), was the repo root
  api/      Hono on Bun
  worker/   GTFS importer
packages/
  db/       Drizzle schema + migrations (PostGIS)
scripts/    one-off checks, typechecked like everything else
```

## Getting started

```bash
bun install
cp .env.example .env          # adjust ports if 5432/3000 are taken
bun run db:up                 # Postgres 18 + PostGIS 3.6 in Docker
bun run db:migrate
bun run db:seed               # optional sample stops
bun run dev                   # api + mobile via turbo
```

Run one side only: `bun run dev:api` / `bun run dev:mobile`.
Native builds: `bun run ios` / `bun run android`.

## Scripts

| Script | What it does |
| --- | --- |
| `bun run dev` | every package's `dev` task, in parallel |
| `bun run build` | `expo export` for mobile |
| `bun run typecheck` | `tsc --noEmit` across all packages |
| `bun run test` | `bun test` across all packages |
| `bun run check:transit-alignment` | asserts every station sits on the lines it serves (needs the API running) |
| `bun run db:up` / `db:down` / `db:reset` | Docker Postgres lifecycle (`db:reset` drops the volume) |
| `bun run db:generate` | diff the schema into a new SQL migration |
| `bun run db:migrate` | apply pending migrations |
| `bun run db:seed` | insert sample stops |
| `bun run db:studio` | Drizzle Studio |

## Database

`docker-compose.yml` runs `imresamu/postgis:18-3.6-alpine` — the official
`postgis/postgis` images are amd64-only, this one is the same upstream build
published multi-arch so it runs natively on Apple Silicon.

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

```ts
import { api } from '@/lib/api';

const res = await api.api.network.map.$get();
const { routes, stations } = await res.json();   // fully typed
```

Point `EXPO_PUBLIC_API_URL` at your machine's LAN IP when running on a physical
device — `localhost` only resolves on the simulator and web.

Because the app derives its types from the API's *source* — there is no build
step — `bun run typecheck` at the root is what proves the contract still holds:
break a route path and the mobile package stops compiling.

## API structure

One folder per theme under `apps/api/src/routers/`, mirroring the URL tree, so
`routers/network/` serves `/api/network`:

```
routers/network/
  router.ts               GET /map -> handlers
  handlers/*.ts           one file per endpoint: HTTP concerns only
  queries.ts              drizzle + PostGIS, returns rows
  mappers.ts              rows -> DTO. Pure: no db, no Context, unit-testable
  types.ts                the wire contract
  contract.ts             type-level tripwire on the client path
```

Imports point downward only — `router` → `handlers` → `queries`/`mappers` →
`geo`/`http` — and nothing under `routers/` imports `app.ts`.

Adding an endpoint means a file in `handlers/` and a line in `router.ts`. Adding
a theme means a folder and a line in `routers/index.ts`; `app.ts` does not
change. Every router must stay in one chained expression, or `AppType` loses the
route table and the typed client silently degrades to `any`.

Handlers are built with `createFactory().createHandlers()` rather than plain
functions: that is what lets a handler live in its own file without losing the
`c.json()` return type the app infers from.

## Not wired up yet

`apps/mobile` still has an `expo lint` script but ESLint isn't installed, so
there's no `lint` task in `turbo.json`. Run `bunx expo lint` inside
`apps/mobile` once to let Expo scaffold it, then add the task back.
