/**
 * Whatever tells a starting import that no other one holds the network. The
 * interface exists so the rule can be tested without a database; production
 * passes `postgresImportLock`, a session-level PostgreSQL advisory lock that
 * the server drops on its own the moment the connection goes away.
 */
export interface ImportLock {
  acquire(): Promise<boolean>;
  release(): Promise<void>;
}

/**
 * A second import must be refused, never queued.
 *
 * The reload opens with `TRUNCATE`, which waits for an exclusive lock on the
 * network tables — and a waiting exclusive lock parks every later reader behind
 * it. So an import started while another is still running does not merely
 * duplicate work: it takes the API's reads down with it until the first one
 * finishes. Failing fast, before any statement runs, is the only safe answer.
 */
export async function runWithImportLock<T>(lock: ImportLock, run: () => Promise<T>): Promise<T> {
  if (!(await lock.acquire())) {
    throw new Error('A GTFS import is already running — wait for it to finish or stop it first.');
  }
  try {
    return await run();
  } finally {
    await lock.release();
  }
}
