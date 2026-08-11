import { sql } from 'drizzle-orm';
import {
  boolean,
  index,
  integer,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uuid,
} from 'drizzle-orm/pg-core';

import { lineStringWgs84, pointWgs84 } from './columns';

/**
 * Placeholder domain table — a transit stop with a PostGIS point.
 * SRID 4326 is WGS84, i.e. the lon/lat the device's GPS reports.
 */
export const stops = pgTable(
  'stops',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    name: text('name').notNull(),
    location: pointWgs84('location').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .default(sql`now()`),
  },
  (table) => [
    // GiST is what makes "stops near me" queries fast.
    index('stops_location_idx').using('gist', table.location),
  ]
);

export type Stop = typeof stops.$inferSelect;
export type NewStop = typeof stops.$inferInsert;

export const transitRoutes = pgTable('transit_routes', {
  id: text('id').primaryKey(),
  agencyId: text('agency_id').notNull(),
  shortName: text('short_name').notNull(),
  longName: text('long_name').notNull(),
  routeType: integer('route_type').notNull(),
  color: text('color').notNull(),
  textColor: text('text_color').notNull(),
  importedAt: timestamp('imported_at', { withTimezone: true })
    .notNull()
    .default(sql`now()`),
});

export const transitRoutePatterns = pgTable(
  'transit_route_patterns',
  {
    id: text('id').primaryKey(),
    routeId: text('route_id')
      .notNull()
      .references(() => transitRoutes.id, { onDelete: 'cascade' }),
    directionId: integer('direction_id').notNull(),
    headsign: text('headsign').notNull(),
    tripCount: integer('trip_count').notNull(),
    isCanonical: boolean('is_canonical').notNull().default(false),
    geometry: lineStringWgs84('geometry').notNull(),
  },
  (table) => [
    index('transit_route_patterns_geometry_idx').using('gist', table.geometry),
    index('transit_route_patterns_route_idx').on(table.routeId),
  ]
);

export const transitStops = pgTable(
  'transit_stops',
  {
    id: text('id').primaryKey(),
    name: text('name').notNull(),
    location: pointWgs84('location').notNull(),
  },
  (table) => [index('transit_stops_location_idx').using('gist', table.location)]
);

export const transitRoutePatternStops = pgTable(
  'transit_route_pattern_stops',
  {
    patternId: text('pattern_id')
      .notNull()
      .references(() => transitRoutePatterns.id, { onDelete: 'cascade' }),
    stopId: text('stop_id')
      .notNull()
      .references(() => transitStops.id, { onDelete: 'restrict' }),
    stopSequence: integer('stop_sequence').notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.patternId, table.stopSequence] }),
    index('transit_route_pattern_stops_stop_idx').on(table.stopId),
  ]
);

export type TransitRoute = typeof transitRoutes.$inferSelect;
export type TransitRoutePattern = typeof transitRoutePatterns.$inferSelect;
export type TransitStop = typeof transitStops.$inferSelect;
