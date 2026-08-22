import { sql, type SQL } from 'drizzle-orm';

/**
 * A `Date` as a bind parameter a raw statement can actually carry.
 *
 * Drizzle's query builder knows each column's type and hands postgres-js a
 * value it has a serializer for. `db.execute(sql\`…\`)` does not: it goes
 * through postgres-js's `unsafe()` path, where a parameter arrives with no
 * declared type and a `Date` falls through to `Buffer.byteLength()` — an
 * `ERR_INVALID_ARG_TYPE` thrown from inside the driver, at bind time, naming
 * neither the query nor the parameter.
 *
 * So a raw statement sends the instant as ISO text and lets Postgres parse it.
 * The cast is not decoration: without it the parameter is `unknown`, and
 * Postgres only guesses a type from context — which fails outright where the
 * comparison is against another parameter rather than a column.
 */
export function timestamptz(value: Date): SQL {
  return sql`${value.toISOString()}::timestamptz`;
}
