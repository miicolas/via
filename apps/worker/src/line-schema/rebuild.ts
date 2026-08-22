/**
 * Rebuilds the line schema tables from the timetable already in the database.
 *
 * `buildLineSchema` is a pure function of `transit_trips` and
 * `transit_profile_stops`, so a change to the branch rules does not need a
 * GTFS reimport — only this. One transaction: the plan of every line is
 * replaced or nothing is.
 *
 *   bun --env-file=../../.env src/line-schema/rebuild.ts
 */
import { client } from '@via/db';

import { importLineSchemasFromDatabase } from './import-line-schemas';

try {
  await importLineSchemasFromDatabase({ replaceExisting: true });
} finally {
  await client.end();
}
