import { db } from '@via/db';

export type SnapshotTransaction = Parameters<Parameters<typeof db.transaction>[0]>[0];
export type SnapshotTransactionRunner = (
  write: (transaction: SnapshotTransaction) => Promise<void>,
) => Promise<void>;

type SnapshotImport<T> = {
  prepare: (importedAt: Date) => Promise<T>;
  write: (transaction: SnapshotTransaction, rows: T, importedAt: Date) => Promise<void>;
  emptyMessage: string;
  isEmpty?: (rows: T) => boolean;
  onCommit?: () => Promise<void>;
  transaction?: SnapshotTransactionRunner;
};

/**
 * Shared commit boundary for external snapshots. Every importer prepares and
 * validates a complete in-memory replacement before deleting the old rows;
 * a source outage or an empty mapping therefore preserves the last snapshot.
 */
export async function replaceSnapshot<T>({
  prepare,
  write,
  emptyMessage,
  isEmpty = (rows) => Array.isArray(rows) && rows.length === 0,
  onCommit,
  transaction = (write) => db.transaction(write),
}: SnapshotImport<T>) {
  const importedAt = new Date();
  const rows = await prepare(importedAt);
  if (isEmpty(rows)) throw new Error(emptyMessage);

  await transaction(async (transaction) => {
    await write(transaction, rows, importedAt);
  });
  await onCommit?.();

  return { rows, importedAt };
}
