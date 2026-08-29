import { randomUUID } from 'node:crypto';

import { db, importMeta } from '@via/db';

export const TRANSIT_NETWORK_VERSION_KEY = 'transit:network:version';

export type ImportMetaValue = {
  key: string;
  value: string;
  updatedAt: Date;
};

/** Small seam used by tests and by callers that already have a transaction. */
export type NetworkCacheVersionStore = {
  upsertImportMeta: (value: ImportMetaValue) => Promise<void>;
};

type DrizzleInsertStore = {
  insert: (table: unknown) => {
    values: (value: ImportMetaValue) => {
      onConflictDoUpdate: (input: {
        target: unknown;
        set: Pick<ImportMetaValue, 'value' | 'updatedAt'>;
      }) => Promise<unknown>;
    };
  };
};

/**
 * Moves API station metadata to a fresh durable namespace after an enrichment
 * changes. The default store is PostgreSQL; passing a transaction keeps the
 * write in the caller's transaction.
 */
export function bumpTransitNetworkCacheVersion(): Promise<void>;
export function bumpTransitNetworkCacheVersion(
  store: NetworkCacheVersionStore | unknown,
  generation?: string,
): Promise<string>;
export async function bumpTransitNetworkCacheVersion(
  store?: unknown,
  generation: string = randomUUID(),
): Promise<void | string> {
  const target = store ?? db;
  const value: ImportMetaValue = {
    key: TRANSIT_NETWORK_VERSION_KEY,
    value: generation,
    updatedAt: new Date(),
  };

  if (isNetworkCacheVersionStore(target)) {
    await target.upsertImportMeta(value);
    return generation;
  }

  await upsertWithDrizzle(target, value);
  return generation;
}

function isNetworkCacheVersionStore(value: unknown): value is NetworkCacheVersionStore {
  return (
    typeof value === 'object' &&
    value !== null &&
    'upsertImportMeta' in value &&
    typeof value.upsertImportMeta === 'function'
  );
}

async function upsertWithDrizzle(store: unknown, value: ImportMetaValue) {
  const database = store as DrizzleInsertStore;
  await database
    .insert(importMeta)
    .values(value)
    .onConflictDoUpdate({
      target: importMeta.key,
      set: { value: value.value, updatedAt: value.updatedAt },
    });
}
