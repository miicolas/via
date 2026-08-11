# via

Turborepo monorepo: an Expo app, a Hono API, and a PostGIS-backed Postgres.

```
apps/
  mobile/   Expo SDK 57 app (expo-router), was the repo root
  api/      Hono on Bun
packages/
  db/       Drizzle schema + migrations (PostGIS)
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

const res = await api.api.stops.$get({ query: { lat: '48.85', lon: '2.35' } });
const { stops } = await res.json();   // fully typed
```

Point `EXPO_PUBLIC_API_URL` at your machine's LAN IP when running on a physical
device — `localhost` only resolves on the simulator and web.

## Not wired up yet

`apps/mobile` still has an `expo lint` script but ESLint isn't installed, so
there's no `lint` task in `turbo.json`. Run `bunx expo lint` inside
`apps/mobile` once to let Expo scaffold it, then add the task back.
