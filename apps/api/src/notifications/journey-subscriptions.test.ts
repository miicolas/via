import { expect, test } from 'bun:test';
import { PgDialect } from 'drizzle-orm/pg-core';

import { activeJourneyExistsQuery } from './journey-subscriptions';

test('the active journey demand check is an indexed EXISTS query', () => {
  const query = new PgDialect().sqlToQuery(
    activeJourneyExistsQuery(new Date('2026-08-24T12:00:00Z')),
  );

  expect(query.sql.toLowerCase()).toContain('select exists');
  expect(query.sql).toContain('ends_at');
  expect(query.params.some((parameter) => parameter instanceof Date)).toBe(false);
  expect(query.params).toContain('2026-08-24T12:00:00.000Z');
});
