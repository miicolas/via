import { expect, test } from 'bun:test';

import {
  replaceSnapshot,
  type SnapshotTransaction,
} from './snapshot-importer';

test('commits a prepared snapshot before running the post-commit hook', async () => {
  const events: string[] = [];
  const result = await replaceSnapshot({
    prepare: async () => [{ id: 'station-1' }],
    write: async () => {
      events.push('write');
    },
    transaction: async (write) => {
      events.push('transaction');
      await write({} as SnapshotTransaction);
      events.push('committed');
    },
    onCommit: async () => {
      events.push('onCommit');
    },
    emptyMessage: 'empty',
  });

  expect(result.rows).toEqual([{ id: 'station-1' }]);
  expect(events).toEqual(['transaction', 'write', 'committed', 'onCommit']);
});

test('does not delete, write, or bump an empty snapshot', async () => {
  const events: string[] = [];

  await expect(
    replaceSnapshot({
      prepare: async () => [],
      write: async () => {
        events.push('write');
      },
      transaction: async () => {
        events.push('transaction');
      },
      onCommit: async () => {
        events.push('onCommit');
      },
      emptyMessage: 'empty',
    }),
  ).rejects.toThrow('empty');

  expect(events).toEqual([]);
});
