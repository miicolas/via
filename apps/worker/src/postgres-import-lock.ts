import { client } from '@via/db';

import type { ImportLock } from './import-lock';

// Stable two-part advisory key: "VIA" + "GTFS" as signed 32-bit integers.
const VIA_LOCK_NAMESPACE = 0x56_49_41;
const GTFS_IMPORT_LOCK = 0x47_54_46_53;

/** Holds one postgres-js connection for the lifetime of the command. */
export async function reserveGtfsImportLock(): Promise<ImportLock> {
  const connection = await client.reserve();
  let acquired = false;
  let released = false;

  return {
    async acquire() {
      const [row] = await connection<{ acquired: boolean }[]>`
        SELECT pg_try_advisory_lock(${VIA_LOCK_NAMESPACE}, ${GTFS_IMPORT_LOCK}) AS acquired
      `;
      acquired = row?.acquired === true;
      return acquired;
    },
    async release() {
      if (released) return;
      released = true;
      try {
        if (acquired) {
          await connection`
            SELECT pg_advisory_unlock(${VIA_LOCK_NAMESPACE}, ${GTFS_IMPORT_LOCK})
          `;
        }
      } finally {
        connection.release();
      }
    },
  };
}
