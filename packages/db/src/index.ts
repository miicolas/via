import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';

import * as schema from './schema';

type PostgresClient = ReturnType<typeof postgres>;
type Database = ReturnType<typeof drizzle>;

function databaseURL() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error(
      'DATABASE_URL is not set. Copy .env.example to .env at the repo root.'
    );
  }
  return url;
}

let clientInstance: PostgresClient | undefined;
let dbInstance: Database | undefined;
let jobClientInstance: PostgresClient | undefined;
let jobDbInstance: Database | undefined;

function createClient(max: number) {
  return postgres(databaseURL(), {
    max,
    idle_timeout: 30,
    max_lifetime: 60 * 30,
    // Drizzle's inArray emits a distinct SQL text per list length; with server-side
    // prepared statements each variant is cached per backend for the connection's
    // lifetime, growing Postgres memory unboundedly.
    prepare: false,
  });
}

function getClient() {
  return (clientInstance ??= createClient(Number(process.env.DB_POOL_MAX ?? 5)));
}

function getDatabase() {
  return (dbInstance ??= drizzle(getClient(), { schema }));
}

function getJobClient() {
  return (jobClientInstance ??= createClient(2));
}

function getJobDatabase() {
  return (jobDbInstance ??= drizzle(getJobClient(), { schema }));
}

/**
 * Proxies keep importing schema-only helpers, contract tests and CLI argument
 * parsers independent from DATABASE_URL. The connection is still created on
 * the first real query, with the same actionable error when it is missing.
 */
function lazyProxy<T extends object>(resolve: () => T): T {
  return new Proxy({} as T, {
    get(_target, property) {
      const value = Reflect.get(resolve(), property);
      return typeof value === 'function' ? value.bind(resolve()) : value;
    },
  });
}

/**
 * postgres-js rather than Bun's native SQL: drizzle-kit needs a Node driver
 * for `generate`/`migrate` anyway, so one driver covers both the runtime and
 * the CLI — and keeps the API runnable outside Bun.
 */
export const client = lazyProxy(getClient);
export const db = lazyProxy(getDatabase);

/**
 * Scheduler and delivery jobs have their own small pool. Their claim queries
 * are deliberately isolated from the HTTP pool: a slow APNs cycle must never
 * consume the connections needed to answer a user request or healthcheck.
 */
export const jobClient = lazyProxy(getJobClient);
export const jobDb = lazyProxy(getJobDatabase);

export * from './schema';
export type { LonLat } from './columns';
export { timestamptz } from './sql-values';
export { schema };
