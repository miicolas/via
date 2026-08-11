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
export const client = postgres(url);

export const db = drizzle(client, { schema });

export * from './schema';
export type { LonLat } from './columns';
export { schema };
