import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { db, importMeta } from '@via/db';
import { eq, inArray } from 'drizzle-orm';

import { importGtfsSnapshot, type GtfsImportResult } from '../import-gtfs';
import {
  downloadPrimGtfsSnapshot,
  type HttpValidators,
  type PrimGtfsDownloadResult,
} from './download-gtfs';
import { extractGtfsArchive } from './extract-gtfs-archive';

const PRIM_GTFS_ETAG_KEY = 'gtfs:prim:etag';
const PRIM_GTFS_LAST_MODIFIED_KEY = 'gtfs:prim:last-modified';

export type PrimGtfsSyncResult = GtfsImportResult | { status: 'unchanged' };

export type PrimGtfsSyncAdapters = {
  createTemporaryDirectory(): Promise<string>;
  removeTemporaryDirectory(path: string): Promise<void>;
  loadValidators(): Promise<HttpValidators>;
  download(options: {
    token: string;
    destination: string;
    validators: HttpValidators;
  }): Promise<PrimGtfsDownloadResult>;
  extract(archive: string, destination: string): Promise<void>;
  importSnapshot(path: string): Promise<GtfsImportResult>;
  saveValidators(validators: HttpValidators): Promise<void>;
};

type ImportMetaTransaction = Parameters<Parameters<typeof db.transaction>[0]>[0];

async function upsertMeta(
  tx: ImportMetaTransaction,
  key: string,
  value: string | undefined
) {
  if (!value) {
    await tx.delete(importMeta).where(eq(importMeta.key, key));
    return;
  }
  await tx
    .insert(importMeta)
    .values({ key, value })
    .onConflictDoUpdate({
      target: importMeta.key,
      set: { value, updatedAt: new Date() },
    });
}

const productionAdapters: PrimGtfsSyncAdapters = {
  async createTemporaryDirectory() {
    return mkdtemp(join(tmpdir(), 'via-prim-gtfs-'));
  },
  async removeTemporaryDirectory(path) {
    await rm(path, { recursive: true, force: true });
  },
  async loadValidators() {
    const rows = await db
      .select({ key: importMeta.key, value: importMeta.value })
      .from(importMeta)
      .where(inArray(importMeta.key, [PRIM_GTFS_ETAG_KEY, PRIM_GTFS_LAST_MODIFIED_KEY]));
    const byKey = new Map(rows.map((row) => [row.key, row.value]));
    return {
      etag: byKey.get(PRIM_GTFS_ETAG_KEY),
      lastModified: byKey.get(PRIM_GTFS_LAST_MODIFIED_KEY),
    };
  },
  download: downloadPrimGtfsSnapshot,
  async extract(archive, destination) {
    await extractGtfsArchive(archive, destination);
  },
  importSnapshot: importGtfsSnapshot,
  async saveValidators(validators) {
    await db.transaction(async (tx) => {
      await upsertMeta(tx, PRIM_GTFS_ETAG_KEY, validators.etag);
      await upsertMeta(tx, PRIM_GTFS_LAST_MODIFIED_KEY, validators.lastModified);
    });
  },
};

export async function synchronizePrimGtfs(
  token: string,
  adapters: PrimGtfsSyncAdapters = productionAdapters
): Promise<PrimGtfsSyncResult> {
  if (!token) throw new Error('PRIM_STATIC_DATA_TOKEN is required for GTFS synchronization');

  const temporaryDirectory = await adapters.createTemporaryDirectory();
  const archive = join(temporaryDirectory, 'snapshot.zip');
  const feed = join(temporaryDirectory, 'feed');
  try {
    const validators = await adapters.loadValidators();
    const downloaded = await adapters.download({
      token,
      destination: archive,
      validators,
    });
    if (downloaded.status === 'unchanged') return downloaded;

    await adapters.extract(archive, feed);
    const imported = await adapters.importSnapshot(feed);
    await adapters.saveValidators(downloaded.validators);
    return imported;
  } finally {
    await adapters.removeTemporaryDirectory(temporaryDirectory);
  }
}
