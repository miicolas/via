import { db, importMeta } from '@via/db';
import { eq } from 'drizzle-orm';

import { bumpTransitNetworkCacheVersion } from './network-cache-version';

export const GTFS_FEED_HASH_KEY = 'gtfs:feed:sha256';

type DrizzleInsertStore = {
  insert: (table: unknown) => {
    values: (value: { key: string; value: string; updatedAt?: Date }) => {
      onConflictDoUpdate: (input: {
        target: unknown;
        set: { value: string; updatedAt: Date };
      }) => Promise<unknown>;
    };
  };
};

export type GtfsImportMetadataAdapters = {
  transaction?: (work: (transaction: unknown) => Promise<void>) => Promise<void>;
  writeFeedHash?: (transaction: unknown, feedHash: string) => Promise<void>;
  bumpVersion?: (transaction: unknown) => Promise<void>;
};

/**
 * Record the completed feed and invalidate all network-derived caches in one
 * transaction. A failed second write therefore leaves the previous hash in
 * place, forcing the next run to retry the import.
 */
export async function finalizeGtfsImportMetadata(
  feedHash: string,
  adapters: GtfsImportMetadataAdapters = {},
): Promise<void> {
  if (feedHash.trim().length === 0) {
    throw new Error('GTFS feed hash must not be empty');
  }

  const transaction =
    adapters.transaction ??
    (async (work: (transaction: unknown) => Promise<void>) =>
      db.transaction(async (tx) => work(tx)));
  const writeFeedHash = adapters.writeFeedHash ?? writeFeedHashWithDrizzle;
  const bumpVersion =
    adapters.bumpVersion ??
    ((tx: unknown) => bumpTransitNetworkCacheVersion(tx));

  await transaction(async (tx) => {
    await writeFeedHash(tx, feedHash);
    await bumpVersion(tx);
  });
}

async function writeFeedHashWithDrizzle(transaction: unknown, feedHash: string) {
  const database = transaction as DrizzleInsertStore;
  await database
    .insert(importMeta)
    .values({ key: GTFS_FEED_HASH_KEY, value: feedHash })
    .onConflictDoUpdate({
      target: importMeta.key,
      set: { value: feedHash, updatedAt: new Date() },
    });
}

/** Read helper kept here so the importer's unchanged check uses one key source. */
export async function readStoredGtfsFeedHash() {
  const [stored] = await db
    .select({ value: importMeta.value })
    .from(importMeta)
    .where(eq(importMeta.key, GTFS_FEED_HASH_KEY));
  return stored?.value;
}
