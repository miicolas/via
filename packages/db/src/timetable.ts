import { sql, type SQLWrapper } from 'drizzle-orm';

import { transitTrips } from './schema';

/**
 * Reconstructs an absolute GTFS time from a trip start and a time-profile
 * offset. Keeping this expression here prevents timetable readers from
 * learning the compressed storage representation independently.
 */
export function absoluteTimetableSeconds(offset: SQLWrapper) {
  return sql<number>`${transitTrips.startSeconds} + ${offset}`.mapWith(Number);
}
