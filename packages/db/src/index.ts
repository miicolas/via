import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';

import * as schema from './schema';

const url = process.env.DATABASE_URL;

if (!url) {
  throw new Error(
    'DATABASE_URL is not set. Copy .env.example to .env at the repo root.'
  );
}

/**
 * postgres-js rather than Bun's native SQL: drizzle-kit needs a Node driver
 * for `generate`/`migrate` anyway, so one driver covers both the runtime and
 * the CLI — and keeps the API runnable outside Bun.
 */
export const client = postgres(url, {
  max: Number(process.env.DB_POOL_MAX ?? 5),
  idle_timeout: 30,
  max_lifetime: 60 * 30,
  // Drizzle's inArray emits a distinct SQL text per list length; with server-side
  // prepared statements each variant is cached per backend for the connection's
  // lifetime, growing Postgres memory unboundedly.
  prepare: false,
});

export const db = drizzle(client, { schema });

export * from './schema';
export type { LonLat } from './columns';
export { schema };
