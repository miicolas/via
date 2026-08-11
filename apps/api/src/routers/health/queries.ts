import { db } from '@via/db';
import { sql } from 'drizzle-orm';

/**
 * A round trip that touches the connection pool without reading a table, so a
 * healthy answer means "the API can reach Postgres", not "the schema is right".
 */
export async function isDatabaseReachable(): Promise<boolean> {
  const [{ ok }] = await db.execute<{ ok: number }>(sql`select 1 as ok`);

  return ok === 1;
}
