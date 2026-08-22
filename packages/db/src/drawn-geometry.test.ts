import { expect, test } from 'bun:test';
import { PgDialect } from 'drizzle-orm/pg-core';

import { computeDrawnGeometry } from './drawn-geometry';

test('scopes every PostGIS normalization statement to one route', () => {
  const query = new PgDialect().sqlToQuery(computeDrawnGeometry('IDFM:C01371'));

  expect(query.params.filter((parameter) => parameter === 'IDFM:C01371')).toHaveLength(1);
  expect(query.sql).toContain('"transit_routes"."id" =');
  expect(query.sql).toContain('ST_Buffer(earlier.geometry::geography');
  expect(query.sql).not.toContain('ROWS BETWEEN UNBOUNDED PRECEDING');
});
