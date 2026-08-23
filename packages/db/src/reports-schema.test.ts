import { expect, test } from 'bun:test';
import { getTableConfig } from 'drizzle-orm/pg-core';
import { getTableName } from 'drizzle-orm';

import { reportCurrentVotes, reportEvents } from './schema';

test('worker-owned station snapshots cannot cascade into community reports', () => {
  for (const table of [reportCurrentVotes, reportEvents]) {
    const foreignKeys = getTableConfig(table).foreignKeys;
    expect(foreignKeys).toHaveLength(1);
    const reference = foreignKeys[0]!.reference();
    expect(getTableName(reference.foreignTable)).toBe('users');
    expect(foreignKeys[0]!.onDelete).toBe('cascade');
  }
});
