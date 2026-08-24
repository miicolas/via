import { expect, test } from 'bun:test';
import { PgDialect } from 'drizzle-orm/pg-core';

import { notificationSentTodayWhere } from './inbox-store';

test('the sent-today query binds the Paris day boundary as timestamp text', () => {
  const query = new PgDialect().sqlToQuery(
    notificationSentTodayWhere(
      'user-1',
      new Date('2026-08-24T12:00:00Z'),
      'line',
    ),
  );

  expect(query.params.some((parameter) => parameter instanceof Date)).toBe(false);
  expect(query.params).toContain('2026-08-23T22:00:00.000Z');
  expect(query.sql).toContain('::timestamptz');
});
