import { sql } from 'drizzle-orm';
import {
  boolean,
  date,
  doublePrecision,
  index,
  integer,
  pgTable,
  primaryKey,
  text,
  timestamp,
} from 'drizzle-orm/pg-core';

import { lineStringWgs84, pointWgs84 } from './columns';

/**
 * This module is the side-effect-free half of the package: table definitions and
 * the facts about them, reachable without opening a connection. `@via/db` itself
 * builds the pool at import time, so anything that only needs a shape should
 * come from here.
 */
export type { LonLat } from './columns';
export * from './transit-mode';

export const transitRoutes = pgTable(
  'transit_routes',
  {
    id: text('id').primaryKey(),
    agencyId: text('agency_id').notNull(),
    shortName: text('short_name').notNull(),
    longName: text('long_name').notNull(),
    routeType: integer('route_type').notNull(),
    color: text('color').notNull(),
    textColor: text('text_color').notNull(),
    /**
     * When this line was last imported. No code reads it — it is the answer to
     * "is this network stale?", a question only a human asks, and the importer is
     * the only thing that can answer it.
     */
    importedAt: timestamp('imported_at', { withTimezone: true })
      .notNull()
      .default(sql`now()`),
  },
  (table) => [
    // Every network query filters on the mode. Irrelevant while only the 16
    // metro lines are imported; decisive once the full IDFM feed lands, where
    // metro is a rounding error next to the bus routes.
    index('transit_routes_route_type_idx').on(table.routeType),
  ]
);

export const transitRoutePatterns = pgTable(
  'transit_route_patterns',
  {
    id: text('id').primaryKey(),
    routeId: text('route_id')
      .notNull()
      .references(() => transitRoutes.id, { onDelete: 'cascade' }),
    directionId: integer('direction_id').notNull(),
    headsign: text('headsign').notNull(),
    /**
     * How this branch fared, and whether it won.
     *
     * Neither column has an application reader, and both are kept on purpose:
     * they are the *outputs* of the editorial policy in
     * `apps/worker/src/pattern-selection.ts`, which decides from `tripCount`
     * which branches of a line are real enough to draw. Without them the
     * database cannot answer "why is this branch on the map and that one not?",
     * and re-deriving the answer costs a full GTFS re-import.
     */
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
    /**
     * The stop projected onto this pattern's track, and how far it had to move.
     *
     * GTFS records a station at its street entrance, tens of metres off the
     * alignment, so the map has to snap it onto the line. That projection only
     * changes when a GTFS import runs, yet it used to be recomputed by PostGIS on
     * every single request — `ST_ClosestPoint(ST_Collect(...))` over every pattern
     * of a route, for every station. Storing it turns the read path into a plain
     * indexed join.
     *
     * Nullable because the value depends on a join, so it cannot be computed in
     * the INSERT, and a Postgres generated column may not reference another table.
     * The importer fills both in the same transaction; readers filter on NOT NULL,
     * which also protects them from an interrupted import.
     *
     * The rule that writes and reads them lives in `@via/db/projection`.
     */
    snappedLocation: pointWgs84('snapped_location'),
    snapDistanceM: doublePrecision('snap_distance_m'),
  },
  (table) => [
    primaryKey({ columns: [table.patternId, table.stopSequence] }),
    index('transit_route_pattern_stops_stop_idx').on(table.stopId),
  ]
);

/**
 * `calendar` + `calendar_dates` expanded by the importer into one row per day a
 * service actually runs, over the feed's validity window. "Which services run
 * on date D?" then needs no weekday logic and no exception handling at read
 * time — those were resolved once, at import.
 */
export const transitServiceDates = pgTable(
  'transit_service_dates',
  {
    serviceId: text('service_id').notNull(),
    date: date('date').notNull(),
  },
  (table) => [primaryKey({ columns: [table.serviceId, table.date] })]
);

/**
 * Theoretical departures, flattened from `stop_times`: one row per stop call,
 * no `trips` table to join back to. The target question — next N departures at
 * stop X after time H for the services of day D — is a single indexed range
 * scan. Kept raw rather than pre-bucketed by day type: `transit_service_dates`
 * already absorbed the calendar, and day-type aggregation breaks on the first
 * `calendar_dates` exception.
 */
export const transitStopDepartures = pgTable(
  'transit_stop_departures',
  {
    stopId: text('stop_id')
      .notNull()
      .references(() => transitStops.id, { onDelete: 'cascade' }),
    routeId: text('route_id')
      .notNull()
      .references(() => transitRoutes.id, { onDelete: 'cascade' }),
    directionId: integer('direction_id').notNull(),
    headsign: text('headsign').notNull(),
    serviceId: text('service_id').notNull(),
    /**
     * Seconds since the service day's midnight, GTFS semantics preserved:
     * "25:12:00" stays 90 720, because that departure belongs to the previous
     * day's service even though it happens after midnight.
     */
    departureSeconds: integer('departure_seconds').notNull(),
  },
  (table) => [
    index('transit_stop_departures_lookup_idx').on(
      table.stopId,
      table.serviceId,
      table.departureSeconds
    ),
  ]
);

export type TransitRoute = typeof transitRoutes.$inferSelect;
export type TransitRoutePattern = typeof transitRoutePatterns.$inferSelect;
export type TransitStop = typeof transitStops.$inferSelect;
