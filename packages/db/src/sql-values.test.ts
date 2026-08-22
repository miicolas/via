import { expect, test } from 'bun:test';
import { sql } from 'drizzle-orm';
import { PgDialect } from 'drizzle-orm/pg-core';

import { timestamptz } from './sql-values';

test('sends an instant as ISO text a raw statement can bind', () => {
  const instant = new Date('2026-08-22T17:59:10.834Z');
  const query = new PgDialect().sqlToQuery(
    sql`SELECT 1 WHERE created_at < ${timestamptz(instant)}`
  );

  expect(query.params).toEqual(['2026-08-22T17:59:10.834Z']);
  expect(query.params.some((parameter) => parameter instanceof Date)).toBe(false);
  expect(query.sql).toContain('::timestamptz');
});
