import { sql } from 'drizzle-orm';
import {
  boolean,
  check,
  date,
  doublePrecision,
  foreignKey,
  index,
  integer,
  jsonb,
  pgTable,
  primaryKey,
  real,
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

/** Raw GTFS/IDFM stop identifiers folded into Via's canonical stop-area id. */
export const transitStopAliases = pgTable(
  'transit_stop_aliases',
  {
    sourceId: text('source_id').primaryKey(),
    stopId: text('stop_id')
      .notNull()
      .references(() => transitStops.id, { onDelete: 'cascade' }),
  },
  (table) => [index('transit_stop_aliases_stop_idx').on(table.stopId)]
);

export const STATION_FACT_CONDITIONS = [
  'autonomous',
  'staffAssistance',
  'reservationRequired',
] as const;
export type StationFactCondition = (typeof STATION_FACT_CONDITIONS)[number];

/**
 * One row per fact known about a station: `kind` names the concept,
 * `condition` carries Via's verdict, and provenance rides on the row. A new
 * attribute (elevators, facilities…) is a new `kind`, not a new table — so the
 * n-th attribute touches no existing query. Importers translate source
 * vocabulary into `condition` at write time; readers never see source codes.
 */
export const stationFacts = pgTable(
  'station_facts',
  {
    stopId: text('stop_id')
      .notNull()
      .references(() => transitStops.id, { onDelete: 'cascade' }),
    kind: text('kind', { enum: ['accessibility'] }).notNull(),
    condition: text('condition', { enum: STATION_FACT_CONDITIONS }).notNull(),
    /** Displayable free text from the source, e.g. the IDFM agent-hours note. */
    detail: text('detail'),
    /** Which dataset produced the row, e.g. 'idfm:acces-gare'. */
    source: text('source').notNull(),
    /** The raw id the source used for this station, kept as its trace. */
    sourceRef: text('source_ref').notNull(),
    /** When the source itself says its data was last revised; null if it doesn't. */
    sourceUpdatedAt: timestamp('source_updated_at', { withTimezone: true }),
    importedAt: timestamp('imported_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.stopId, table.kind] }),
    uniqueIndex('station_facts_kind_source_ref_uidx').on(table.kind, table.sourceRef),
    check(
      'station_facts_condition_check',
      sql`${table.condition} IN ('autonomous', 'staffAssistance', 'reservationRequired')`
    ),
  ]
);

/**
 * Relative hourly validation profiles for the three public-transit day types.
 * `peakRatio` is calculated at import time so readers only decide the current
 * level thresholds; the raw station-relative share remains available for
 * future displays without exposing the source table wholesale.
 */
export const stationHourProfiles = pgTable(
  'station_hour_profiles',
  {
    stopId: text('stop_id')
      .notNull()
      .references(() => transitStops.id, { onDelete: 'cascade' }),
    dayType: text('day_type', { enum: ['weekday', 'saturday', 'sunday'] }).notNull(),
    hour: integer('hour').notNull(),
    share: real('share').notNull(),
    peakRatio: real('peak_ratio').notNull(),
    source: text('source').notNull(),
    sourceUpdatedAt: timestamp('source_updated_at', { withTimezone: true }).notNull(),
    importedAt: timestamp('imported_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.stopId, table.dayType, table.hour] }),
    index('station_hour_profiles_day_hour_idx').on(table.dayType, table.hour),
  ]
);

/**
 * A street-level way in or out of a station, as the IDFM stop referential
 * declares it: the door a traveller is told to take, `number` being the figure
 * printed on the signage above it.
 *
 * Not a `station_facts` kind: that table holds one row per station per kind, and
 * a station has many exits. Same provenance columns, deliberately — both are
 * snapshots of an external referential and both must be able to say how old they
 * are.
 */
export const stationExits = pgTable(
  'station_exits',
  {
    /** The referential's access id, prefixed like every other IDFM id we store. */
    id: text('id').primaryKey(),
    stopId: text('stop_id')
      .notNull()
      .references(() => transitStops.id, { onDelete: 'cascade' }),
    /** Street-facing name, e.g. 'pl. du Châtelet'. */
    name: text('name').notNull(),
    /** The number riders see on the signage; absent from a few accesses. */
    number: integer('number'),
    detail: text('detail'),
    location: pointWgs84('location').notNull(),
    source: text('source').notNull(),
    sourceRef: text('source_ref').notNull(),
    sourceUpdatedAt: timestamp('source_updated_at', { withTimezone: true }),
    importedAt: timestamp('imported_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    index('station_exits_stop_idx').on(table.stopId),
    index('station_exits_location_idx').using('gist', table.location),
  ]
);

export const BOARDING_POSITION_ZONES = ['front', 'middle', 'rear'] as const;
export type BoardingPositionZone = (typeof BOARDING_POSITION_ZONES)[number];

export const BOARDING_POSITION_EQUIPMENTS = ['escalator', 'lift', 'stairs'] as const;
export type BoardingPositionEquipment = (typeof BOARDING_POSITION_EQUIPMENTS)[number];

/**
 * Which carriage to ride in so the doors open in front of a given exit or
 * connecting platform.
 *
 * Keyed by *quay*, not by station: a quay is direction-specific, and the advice
 * flips with the direction — Châtelet line 7 is carriage 5 of 5 from one quay
 * and carriage 1 of 5 from the other, because carriages count from the head of
 * the train. Collapsing the two into a station would silently send half the
 * riders to the wrong end of the platform. That is also why `fromQuayId` and
 * `targetId` carry no foreign key: `transit_stops` holds canonical stations, and
 * these are one level finer. The importer validates them against
 * `transit_stop_aliases` instead.
 */
export const boardingPositions = pgTable(
  'boarding_positions',
  {
    /** The quay the traveller arrives on, e.g. 'IDFM:463060'. */
    fromQuayId: text('from_quay_id').notNull(),
    /** A `station_exits.id` or, for a connection, the next line's quay id. */
    targetId: text('target_id').notNull(),
    targetKind: text('target_kind', { enum: ['exit', 'transfer'] }).notNull(),
    routeId: text('route_id').notNull(),
    car: integer('car').notNull(),
    /** The line's nominal train length — a short trainset makes this optimistic. */
    carCount: integer('car_count').notNull(),
    zone: text('zone', { enum: BOARDING_POSITION_ZONES }).notNull(),
    /** What the walk from the doors to the target uses, when the source says so. */
    equipment: text('equipment', { enum: BOARDING_POSITION_EQUIPMENTS }),
    source: text('source').notNull(),
    sourceUpdatedAt: timestamp('source_updated_at', { withTimezone: true }),
    importedAt: timestamp('imported_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.fromQuayId, table.targetId] }),
    check('boarding_positions_car_check', sql`${table.car} BETWEEN 1 AND ${table.carCount}`),
  ]
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
    profileKey: integer('profile_key')
      .notNull()
      .references(() => transitTimeProfiles.id),
    /** Departure at the trip's first call; absolute times are `startSeconds + offset`. */
    startSeconds: integer('start_seconds').notNull(),
  },
  (table) => [
    index('transit_trips_service_route_idx').on(table.serviceId, table.routeId),
    index('transit_trips_shape_idx').on(table.shapeId),
    index('transit_trips_profile_idx').on(table.profileKey),
  ]
);

/**
 * A time profile is the schedule of a trip expressed relative to its first
 * departure. The IDFM feed's ~14.5M stop-time calls collapse into ~144k
 * distinct profiles (most trips are the same run at a different clock time),
 * so storing offsets once per profile instead of absolute times once per trip
 * shrinks the timetable ~6×. This table only anchors the dense import-assigned
 * ids; the calls live in `transit_profile_stops`.
 */
export const transitTimeProfiles = pgTable('transit_time_profiles', {
  id: integer('id').primaryKey(),
});

export const transitProfileStops = pgTable(
  'transit_profile_stops',
  {
    profileKey: integer('profile_key')
      .notNull()
      .references(() => transitTimeProfiles.id, { onDelete: 'cascade' }),
    /** Dense 0..n-1 call order within the profile. */
    position: integer('position').notNull(),
    stopKey: integer('stop_key')
      .notNull()
      .references(() => transitStops.numericId, { onDelete: 'cascade' }),
    /** Seconds relative to the trip's first departure; may be ≤ 0 on the first call. */
    arrivalOffset: integer('arrival_offset').notNull(),
    /** Seconds relative to the trip's first departure; 0 on the first call. */
    departureOffset: integer('departure_offset').notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.profileKey, table.position] }),
    index('transit_profile_stops_stop_idx').on(table.stopKey),
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

/**
 * One row per direction of a line: the label riders pick a platform by,
 * derived at import from the real termini of the merged schema — never from
 * `trip_headsign`, which is a mission code (DUCK, ZEUS) on RER/Transilien.
 */
export const transitLineDirections = pgTable(
  'transit_line_directions',
  {
    routeId: text('route_id')
      .notNull()
      .references(() => transitRoutes.id, { onDelete: 'cascade' }),
    directionId: integer('direction_id').notNull(),
    /** Termini busiest first, e.g. "Marne-la-Vallée – Chessy / Boissy-St-Léger". */
    label: text('label').notNull(),
  },
  (table) => [primaryKey({ columns: [table.routeId, table.directionId] })]
);

/**
 * The complete, rider-facing schema of a line: every station of a direction in
 * reading order, decomposed into a common trunk and named branch sections.
 *
 * Deliberately separate from `transit_route_pattern_stops`, which stores one
 * representative trip's calls per pattern and feeds the map (snapping, drawn
 * geometry). A semi-direct RER mission skips stations, so the map's table can
 * never answer "list every station of the line"; this one is built by merging
 * the stop_times of *all* trips at import (`apps/worker/src/line-schema/`).
 */
export const transitLineSchemaStops = pgTable(
  'transit_line_schema_stops',
  {
    routeId: text('route_id')
      .notNull()
      .references(() => transitRoutes.id, { onDelete: 'cascade' }),
    directionId: integer('direction_id').notNull(),
    /** Render order of the section within the direction. */
    sectionIndex: integer('section_index').notNull(),
    sectionRole: text('section_role', { enum: ['trunk', 'branch'] }).notNull(),
    /** Worker-computed, e.g. "Branche Cergy"; NULL for the trunk. */
    sectionLabel: text('section_label'),
    /**
     * Origin and terminus stops of the service groups whose trains call in
     * this section — the trunk lists every group, a branch only its own.
     * Two sections lie on one physical path iff their groups intersect on
     * both sides; the client needs this to project a disruption that spans
     * trunk, shared sub-trunk and leaf branch without any fork geometry.
     */
    sectionOrigins: text('section_origins').array().notNull(),
    sectionTermini: text('section_termini').array().notNull(),
    /** Stop order within the section. */
    position: integer('position').notNull(),
    stopId: text('stop_id')
      .notNull()
      .references(() => transitStops.id, { onDelete: 'restrict' }),
  },
  (table) => [
    primaryKey({
      columns: [table.routeId, table.directionId, table.sectionIndex, table.position],
    }),
    index('transit_line_schema_stops_route_idx').on(table.routeId),
  ]
);

export const transitShapes = pgTable('transit_shapes', {
  id: text('id').primaryKey(),
  geometry: lineStringWgs84('geometry'),
});

/**
 * Importer bookkeeping. The GTFS worker stores the hash of the last fully
 * imported feed here and skips the reload when the feed has not changed —
 * a full reload rewrites millions of rows, so an unchanged feed must cost
 * nothing.
 */
export const importMeta = pgTable('import_meta', {
  key: text('key').primaryKey(),
  value: text('value').notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
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
  isAnonymous: boolean('is_anonymous').notNull().default(false),
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

/**
 * Per-account data kept locally on iOS and reconciled through operation UUIDs.
 *
 * `station_id` deliberately has no FK to `transit_stops`: the GTFS import
 * prunes stops no longer served, and a cascade would silently destroy user
 * favorites over a feed hiccup. A favorite is a self-contained snapshot
 * (name + coordinate); the client resolves route badges from the map and
 * degrades gracefully when the station is gone.
 */
export const accountFavoriteStations = pgTable(
  'account_favorite_stations',
  {
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    stationId: text('station_id').notNull(),
    name: text('name').notNull(),
    latitude: doublePrecision('latitude'),
    longitude: doublePrecision('longitude'),
    savedAt: timestamp('saved_at', { withTimezone: true }).notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.userId, table.stationId] }),
    index('account_favorite_stations_user_saved_idx').on(table.userId, table.savedAt),
  ]
);

/**
 * Home and work slots keyed by composite search id. Favorite stations live in
 * `account_favorite_stations`; a second representation under a 'favorite' role
 * here was removed rather than kept as a parallel truth.
 */
export const accountPlaces = pgTable(
  'account_places',
  {
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    id: text('id').notNull(),
    role: text('role', { enum: ['home', 'work'] }).notNull(),
    kind: text('kind', { enum: ['station', 'address'] }).notNull(),
    name: text('name').notNull(),
    context: text('context'),
    latitude: doublePrecision('latitude').notNull(),
    longitude: doublePrecision('longitude').notNull(),
    savedAt: timestamp('saved_at', { withTimezone: true }).notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.userId, table.id] }),
    index('account_places_user_role_idx').on(table.userId, table.role),
    check('account_places_role_check', sql`${table.role} IN ('home', 'work')`),
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

/**
 * One current APNs device token per app installation. The installation id is
 * generated by the client and lets a token rotate without leaving a previous
 * row attached to the same account. A token is unique per app/environment so
 * signing out and signing in again can safely re-associate the installation.
 */
export const notificationDevices = pgTable(
  'notification_devices',
  {
    installationId: text('installation_id').primaryKey(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    deviceToken: text('device_token').notNull(),
    bundleId: text('bundle_id').notNull(),
    environment: text('environment', {
      enum: ['sandbox', 'production'],
    }).notNull(),
    appVersion: text('app_version'),
    osVersion: text('os_version'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex('notification_devices_token_uidx').on(table.bundleId, table.environment, table.deviceToken),
    index('notification_devices_user_idx').on(table.userId),
    uniqueIndex('notification_devices_installation_user_uidx').on(table.installationId, table.userId),
  ]
);

export type NotificationRouteWindow = {
  routeId: string;
  startsAt: number;
  endsAt: number;
};

/**
 * @deprecated Physical compatibility only for API replicas from the ae27
 * rollout. New code never reads or writes these ActivityKit tokens. Migration
 * 0026 purges their contents; drop both tables after the old replicas drain.
 */
export const notificationLiveActivities = pgTable(
  'notification_live_activities',
  {
    activityId: text('activity_id').primaryKey(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    installationId: text('installation_id')
      .notNull()
      .references(() => notificationDevices.installationId, { onDelete: 'cascade' }),
    journeyId: text('journey_id').notNull(),
    activityToken: text('activity_token').notNull(),
    bundleId: text('bundle_id').notNull(),
    environment: text('environment', { enum: ['sandbox', 'production'] }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex('notification_live_activities_token_uidx').on(
      table.bundleId,
      table.environment,
      table.activityToken
    ),
    index('notification_live_activities_user_idx').on(table.userId),
    index('notification_live_activities_journey_idx').on(table.journeyId),
    index('notification_live_activities_installation_idx').on(table.installationId),
  ]
);

/** @deprecated See `notificationLiveActivities`; retained for one rollout window. */
export const notificationLiveActivityStartTokens = pgTable(
  'notification_live_activity_start_tokens',
  {
    installationId: text('installation_id')
      .primaryKey()
      .references(() => notificationDevices.installationId, { onDelete: 'cascade' }),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    pushToStartToken: text('push_to_start_token').notNull(),
    bundleId: text('bundle_id').notNull(),
    environment: text('environment', { enum: ['sandbox', 'production'] }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex('notification_live_activity_start_tokens_token_uidx').on(
      table.bundleId,
      table.environment,
      table.pushToStartToken
    ),
    index('notification_live_activity_start_tokens_user_idx').on(table.userId),
  ]
);

/**
 * The monitor claims one shard at a time, so the column and every reader must
 * agree on the count: a reader using fewer shards never sees the rest.
 */
export const NOTIFICATION_DELIVERY_SHARD_COUNT = 64;

export const NOTIFICATION_CATEGORIES = [
  'journey',
  'commute',
  'line',
  'station',
  'digest',
  'recommendation',
] as const;
export type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number];

export const NOTIFICATION_SEVERITIES = ['attention', 'disrupted', 'suspended'] as const;
export type NotificationSeverity = (typeof NOTIFICATION_SEVERITIES)[number];

export type NotificationCategoryPreference = {
  category: NotificationCategory;
  enabled: boolean;
  minimumSeverity: NotificationSeverity;
  dailyCap?: number;
};

export type NotificationLocation = {
  id: string;
  kind: 'station' | 'address';
  name: string;
  context?: string;
  latitude: number;
  longitude: number;
};

export type NotificationTimeWindow = {
  startMinute: number;
  endMinute: number;
};

export const notificationPreferences = pgTable(
  'notification_preferences',
  {
    userId: text('user_id')
      .primaryKey()
      .references(() => users.id, { onDelete: 'cascade' }),
    enabled: boolean('enabled').notNull().default(true),
    timeZone: text('time_zone').notNull().default('Europe/Paris'),
    quietHoursStartMinute: integer('quiet_hours_start_minute'),
    quietHoursEndMinute: integer('quiet_hours_end_minute'),
    mutedOnWeekends: boolean('muted_on_weekends').notNull().default(false),
    mutedOnHolidays: boolean('muted_on_holidays').notNull().default(false),
    minimumSeverity: text('minimum_severity', { enum: NOTIFICATION_SEVERITIES })
      .notNull()
      .default('attention'),
    dailyCap: integer('daily_cap').notNull().default(20),
    categories: jsonb('categories')
      .$type<NotificationCategoryPreference[]>()
      .notNull()
      .default(sql`'[]'::jsonb`),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [check('notification_preferences_time_zone_check', sql`${table.timeZone} = 'Europe/Paris'`)]
);

export const notificationSchedules = pgTable(
  'notification_schedules',
  {
    id: text('id').primaryKey(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    kind: text('kind', { enum: ['commute', 'digest'] }).notNull(),
    label: text('label').notNull(),
    revision: integer('revision').notNull().default(1),
    origin: jsonb('origin').$type<NotificationLocation>(),
    destination: jsonb('destination').$type<NotificationLocation>(),
    routeIds: text('route_ids').array().notNull().default(sql`'{}'::text[]`),
    daysOfWeek: integer('days_of_week').array().notNull().default(sql`'{}'::integer[]`),
    departureMinute: integer('departure_minute').notNull(),
    leadMinutes: integer('lead_minutes').notNull().default(10),
    skipHolidays: boolean('skip_holidays').notNull().default(false),
    enabled: boolean('enabled').notNull().default(true),
    pausedUntil: timestamp('paused_until', { withTimezone: true }),
    timeZone: text('time_zone').notNull().default('Europe/Paris'),
    savedAt: timestamp('saved_at', { withTimezone: true }).notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (table) => [
    index('notification_schedules_user_idx').on(table.userId, table.id),
    index('notification_schedules_active_idx')
      .on(table.userId, table.enabled)
      .where(sql`${table.enabled} = true AND ${table.deletedAt} IS NULL`),
    check('notification_schedules_time_zone_check', sql`${table.timeZone} = 'Europe/Paris'`),
  ]
);

export const notificationAlertSubscriptions = pgTable(
  'notification_alert_subscriptions',
  {
    id: text('id').primaryKey(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    topicKind: text('topic_kind', { enum: ['line', 'station'] }).notNull(),
    topicId: text('topic_id').notNull(),
    label: text('label').notNull(),
    daysOfWeek: integer('days_of_week').array().notNull().default(sql`'{}'::integer[]`),
    windows: jsonb('windows').$type<NotificationTimeWindow[]>().notNull(),
    minimumSeverity: text('minimum_severity', { enum: NOTIFICATION_SEVERITIES })
      .notNull()
      .default('attention'),
    enabled: boolean('enabled').notNull().default(true),
    savedAt: timestamp('saved_at', { withTimezone: true }).notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
  },
  (table) => [
    index('notification_alert_subscriptions_user_idx').on(table.userId, table.id),
    index('notification_alert_subscriptions_topic_idx')
      .on(table.topicKind, table.topicId)
      .where(sql`${table.enabled} = true AND ${table.deletedAt} IS NULL`),
    uniqueIndex('notification_alert_subscriptions_user_topic_uidx')
      .on(table.userId, table.topicKind, table.topicId)
      .where(sql`${table.deletedAt} IS NULL`),
  ]
);

export const notificationOccurrences = pgTable(
  'notification_occurrences',
  {
    id: text('id').primaryKey(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    scheduleId: text('schedule_id').references(() => notificationSchedules.id, {
      onDelete: 'set null',
    }),
    category: text('category', { enum: NOTIFICATION_CATEGORIES }).notNull(),
    scheduleRevision: integer('schedule_revision').notNull().default(1),
    dueAt: timestamp('due_at', { withTimezone: true }).notNull(),
    state: text('state', { enum: ['pending', 'sending', 'sent', 'dropped'] })
      .notNull()
      .default('pending'),
    dropReason: text('drop_reason'),
    attempts: integer('attempts').notNull().default(0),
    leaseUntil: timestamp('lease_until', { withTimezone: true }),
    dedupeKey: text('dedupe_key').notNull().unique(),
    payload: jsonb('payload').$type<Record<string, unknown>>().notNull(),
    deliveryShard: integer('delivery_shard').generatedAlwaysAs(
      sql.raw(
        `mod(hashtextextended(user_id, 0) & 9223372036854775807, ${NOTIFICATION_DELIVERY_SHARD_COUNT})`
      )
    ),
  },
  (table) => [
    index('notification_occurrences_pending_idx')
      .on(table.dueAt, table.id)
      .where(sql`${table.state} = 'pending'`),
    index('notification_occurrences_sending_idx')
      .on(table.leaseUntil)
      .where(sql`${table.state} = 'sending'`),
    index('notification_occurrences_user_idx').on(table.userId, table.dueAt),
  ]
);

export const notificationInbox = pgTable(
  'notification_inbox',
  {
    id: text('id').primaryKey(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    occurrenceId: text('occurrence_id').references(() => notificationOccurrences.id, {
      onDelete: 'set null',
    }),
    category: text('category', { enum: NOTIFICATION_CATEGORIES }).notNull(),
    title: text('title').notNull(),
    body: text('body').notNull(),
    deepLink: text('deep_link'),
    topicKind: text('topic_kind', { enum: ['line', 'station'] }),
    topicId: text('topic_id'),
    severity: text('severity', { enum: NOTIFICATION_SEVERITIES }),
    dropReason: text('drop_reason'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    readAt: timestamp('read_at', { withTimezone: true }),
  },
  (table) => [
    uniqueIndex('notification_inbox_user_occurrence_uidx')
      .on(table.userId, table.occurrenceId)
      .where(sql`${table.occurrenceId} IS NOT NULL`),
    index('notification_inbox_cursor_idx').on(table.userId, table.createdAt, table.id),
    index('notification_inbox_unread_idx')
      .on(table.userId)
      .where(sql`${table.readAt} IS NULL`),
  ]
);

export const notificationMutes = pgTable(
  'notification_mutes',
  {
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    scope: text('scope', { enum: ['category', 'topic'] }).notNull(),
    key: text('key').notNull(),
    mutedUntil: timestamp('muted_until', { withTimezone: true }),
  },
  (table) => [
    primaryKey({ columns: [table.userId, table.scope, table.key] }),
    index('notification_mutes_active_idx').on(table.userId, table.scope, table.key),
  ]
);

/**
 * One authenticated installation can follow one journey for disruption
 * alerts. The route ids are snapshotted with the timetable so the monitor
 * never needs to decode the full journey again.
 */
export const notificationJourneySubscriptions = pgTable(
  'notification_journey_subscriptions',
  {
    installationId: text('installation_id').primaryKey(),
    userId: text('user_id').notNull(),
    journeyId: text('journey_id').notNull(),
    deliveryShard: integer('delivery_shard').generatedAlwaysAs(
      sql.raw(
        `mod(hashtextextended(installation_id, 0) & 9223372036854775807, ${NOTIFICATION_DELIVERY_SHARD_COUNT})`
      )
    ),
    /** @deprecated Dual-write compatibility for ae27 replicas. */
    routeIds: text('route_ids').array().notNull().default(sql`'{}'::text[]`),
    routeWindows: jsonb('route_windows').$type<NotificationRouteWindow[]>().notNull(),
    startsAt: timestamp('starts_at', { withTimezone: true }).notNull(),
    endsAt: timestamp('ends_at', { withTimezone: true }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    index('notification_journey_subscriptions_user_idx').on(table.userId),
    index('notification_journey_subscriptions_journey_idx').on(table.journeyId),
    index('notification_journey_subscriptions_ends_idx').on(table.endsAt),
    index('notification_journey_subscriptions_starts_idx').on(table.startsAt),
    index('notification_journey_subscriptions_delivery_shard_idx').on(
      table.deliveryShard,
      table.installationId
    ),
    foreignKey({
      columns: [table.installationId, table.userId],
      foreignColumns: [notificationDevices.installationId, notificationDevices.userId],
      name: 'notification_journey_subscriptions_installation_user_fk',
    }).onDelete('cascade'),
  ]
);

export type TransitRoute = typeof transitRoutes.$inferSelect;
export type TransitRoutePattern = typeof transitRoutePatterns.$inferSelect;
export type TransitStop = typeof transitStops.$inferSelect;
export type TransitStopAlias = typeof transitStopAliases.$inferSelect;
export type StationFact = typeof stationFacts.$inferSelect;
export type StationHourProfile = typeof stationHourProfiles.$inferSelect;
export type TransitTrip = typeof transitTrips.$inferSelect;
export type TransitLineSchemaStop = typeof transitLineSchemaStops.$inferSelect;
export type NotificationPreference = typeof notificationPreferences.$inferSelect;
export type NotificationSchedule = typeof notificationSchedules.$inferSelect;
export type NotificationAlertSubscription = typeof notificationAlertSubscriptions.$inferSelect;
export type NotificationOccurrence = typeof notificationOccurrences.$inferSelect;
export type NotificationInboxItem = typeof notificationInbox.$inferSelect;
export type NotificationMute = typeof notificationMutes.$inferSelect;
