import { sql } from 'drizzle-orm';
import {
  boolean,
  date,
  doublePrecision,
  index,
  integer,
  pgTable,
  primaryKey,
  serial,
  text,
  timestamp,
  uniqueIndex,
} from 'drizzle-orm/pg-core';

import { lineStringWgs84, multiLineStringWgs84, pointWgs84 } from './columns';

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
    // Every network query filters on the mode. Decisive with the full IDFM feed,
    // where metro is a rounding error next to the bus routes.
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
    /** Bus patterns keep their calls and destinations, but deliberately no map trace. */
    geometry: lineStringWgs84('geometry'),
    /**
     * The normalized track this pattern contributes to the map: the canonical
     * spine untouched, a real branch reduced to what leaves the already-drawn
     * track, everything else empty.
     *
     * It only changes when an import runs, yet it used to be recomputed by
     * PostGIS on every network request — windowed ST_Union + ST_Buffer +
     * ST_Difference, seconds of work per call. Stored instead, following the
     * `snapped_location` precedent below. Nullable because bus patterns never
     * get one and an interrupted import may leave gaps; readers filter on
     * NOT NULL. The rule that writes it lives in `@via/db/drawn-geometry`.
     */
    drawnGeometry: multiLineStringWgs84('drawn_geometry'),
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
    /** Compact key used by the 14.8 M-row timetable instead of repeating GTFS text ids. */
    numericId: serial('numeric_id').notNull().unique(),
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
 * Normalized timetable data for journey planning. The departure board keeps a
 * trip identity and stop order to reconstruct complete paths, so one normalized
 * representation serves both the departure board and the planner.
 */
export const transitTrips = pgTable(
  'transit_trips',
  {
    /** Import-local dense key: 669k integers are materially cheaper than GTFS text ids. */
    numericId: integer('numeric_id').primaryKey(),
    id: text('id').notNull().unique(),
    routeId: text('route_id')
      .notNull()
      .references(() => transitRoutes.id, { onDelete: 'cascade' }),
    serviceId: text('service_id').notNull(),
    directionId: integer('direction_id').notNull(),
    headsign: text('headsign').notNull(),
    shapeId: text('shape_id'),
  },
  (table) => [
    index('transit_trips_service_route_idx').on(table.serviceId, table.routeId),
    index('transit_trips_shape_idx').on(table.shapeId),
  ]
);

export const transitTripStopTimes = pgTable(
  'transit_trip_stop_times',
  {
    tripKey: integer('trip_key')
      .notNull()
      .references(() => transitTrips.numericId, { onDelete: 'cascade' }),
    stopKey: integer('stop_key')
      .notNull()
      .references(() => transitStops.numericId, { onDelete: 'cascade' }),
    stopSequence: integer('stop_sequence').notNull(),
    arrivalSeconds: integer('arrival_seconds').notNull(),
    departureSeconds: integer('departure_seconds').notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.tripKey, table.stopSequence] }),
    index('transit_trip_stop_times_stop_departure_idx').on(
      table.stopKey,
      table.departureSeconds
    ),
  ]
);

export const transitStopRoutes = pgTable(
  'transit_stop_routes',
  {
    stopId: text('stop_id')
      .notNull()
      .references(() => transitStops.id, { onDelete: 'cascade' }),
    routeId: text('route_id')
      .notNull()
      .references(() => transitRoutes.id, { onDelete: 'cascade' }),
  },
  (table) => [primaryKey({ columns: [table.stopId, table.routeId] })]
);

export const transitShapes = pgTable('transit_shapes', {
  id: text('id').primaryKey(),
  geometry: lineStringWgs84('geometry'),
});

export const transitTransfers = pgTable(
  'transit_transfers',
  {
    fromStopId: text('from_stop_id')
      .notNull()
      .references(() => transitStops.id, { onDelete: 'cascade' }),
    toStopId: text('to_stop_id')
      .notNull()
      .references(() => transitStops.id, { onDelete: 'cascade' }),
    minTransferSeconds: integer('min_transfer_seconds').notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.fromStopId, table.toStopId] }),
    index('transit_transfers_from_idx').on(table.fromStopId),
  ]
);

/**
 * Better Auth owns these four tables. Their property names intentionally use
 * Better Auth's camel-case model fields while PostgreSQL keeps snake-case
 * column names. The adapter is configured with `usePlural: true`.
 */
export const users = pgTable('users', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  emailVerified: boolean('email_verified').notNull().default(false),
  image: text('image'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  /**
   * Transport preferences, declared to Better Auth as `user.additionalFields`
   * in `apps/api/src/auth/auth.ts` — the two definitions must stay in sync.
   * `preferencesUpdatedAt` is the last-writer-wins clock for the sync
   * protocol; NULL means the user never set preferences.
   */
  preferredModes: text('preferred_modes').array().notNull().default(sql`'{}'::text[]`),
  excludedModes: text('excluded_modes').array().notNull().default(sql`'{}'::text[]`),
  preferencesUpdatedAt: timestamp('preferences_updated_at', { withTimezone: true }),
});

export const sessions = pgTable(
  'sessions',
  {
    id: text('id').primaryKey(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    token: text('token').notNull().unique(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
    ipAddress: text('ip_address'),
    userAgent: text('user_agent'),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
  },
  (table) => [index('sessions_user_id_idx').on(table.userId)]
);

export const accounts = pgTable(
  'accounts',
  {
    id: text('id').primaryKey(),
    accountId: text('account_id').notNull(),
    providerId: text('provider_id').notNull(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    accessToken: text('access_token'),
    refreshToken: text('refresh_token'),
    idToken: text('id_token'),
    accessTokenExpiresAt: timestamp('access_token_expires_at', { withTimezone: true }),
    refreshTokenExpiresAt: timestamp('refresh_token_expires_at', { withTimezone: true }),
    scope: text('scope'),
    password: text('password'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    index('accounts_user_id_idx').on(table.userId),
    uniqueIndex('accounts_provider_account_uidx').on(table.providerId, table.accountId),
  ]
);

export const verifications = pgTable(
  'verifications',
  {
    id: text('id').primaryKey(),
    identifier: text('identifier').notNull(),
    value: text('value').notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [index('verifications_identifier_idx').on(table.identifier)]
);

/** Per-account data kept locally on iOS and reconciled through operation UUIDs. */
export const accountFavoriteStations = pgTable(
  'account_favorite_stations',
  {
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    stationId: text('station_id').notNull(),
    name: text('name').notNull(),
    savedAt: timestamp('saved_at', { withTimezone: true }).notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.userId, table.stationId] }),
    index('account_favorite_stations_user_saved_idx').on(table.userId, table.savedAt),
  ]
);

export const accountRecentSearches = pgTable(
  'account_recent_searches',
  {
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    id: text('id').notNull(),
    kind: text('kind').notNull(),
    name: text('name').notNull(),
    context: text('context'),
    latitude: doublePrecision('latitude').notNull(),
    longitude: doublePrecision('longitude').notNull(),
    savedAt: timestamp('saved_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.userId, table.id] }),
    index('account_recent_searches_user_saved_idx').on(table.userId, table.savedAt),
  ]
);

export const accountSyncOperations = pgTable(
  'account_sync_operations',
  {
    operationId: text('operation_id').primaryKey(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    appliedAt: timestamp('applied_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [index('account_sync_operations_user_idx').on(table.userId)]
);

export type TransitRoute = typeof transitRoutes.$inferSelect;
export type TransitRoutePattern = typeof transitRoutePatterns.$inferSelect;
export type TransitStop = typeof transitStops.$inferSelect;
export type TransitTrip = typeof transitTrips.$inferSelect;
export type TransitTripStopTime = typeof transitTripStopTimes.$inferSelect;
