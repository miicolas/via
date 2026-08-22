import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { access } from 'node:fs/promises';
import { join } from 'node:path';

import { client, db } from '@via/db';
import {
  ROUTE_TYPE,
  importMeta,
  networkMode,
  transitLineDirections,
  transitLineSchemaStops,
  transitProfileStops,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStopAliases,
  transitShapes,
  transitServiceDates,
  transitStopRoutes,
  transitStops,
  transitTimeProfiles,
  transitTrips,
  transitTransfers,
  type LonLat,
  type NetworkMode,
} from '@via/db/schema';
import { computeDrawnGeometry } from '@via/db/drawn-geometry';
import { networkRouteCondition } from '@via/db/network-scope';
import { projectStopsOntoPatterns } from '@via/db/projection';
import { eq, sql } from 'drizzle-orm';
import { RedisClient as BunRedisClient } from 'bun';

import { readCsv, readPositionalCsv, type CsvRow } from './csv';
import { importLineSchemasFromDatabase } from './line-schema/import-line-schemas';
import { selectPatterns, type PatternCandidate } from './pattern-selection';
import { formatCount, formatDuration, logStep, step } from './progress';
import { importSchedules, type ScheduledTrip } from './schedule/import-schedules';
import { addScheduledTrip } from './schedule/scheduled-trips';
import { importShapes } from './shapes/import-shapes';
import { refreshAccessibilitySnapshot } from './accessibility/import-accessibility';
import { refreshWayfindingSnapshot } from './wayfinding/import-wayfinding';

/**
 * A route once its required fields have actually been checked.
 *
 * The previous shape was `row as RouteRow`, an unchecked cast that told the
 * compiler validation had happened. `agency_id` is optional in GTFS, so a feed
 * with a single agency produced a NOT NULL violation a hundred lines later,
 * inside the transaction, far from the row that caused it.
 */
type ImportedRoute = {
  id: string;
  agencyId: string;
  shortName: string;
  longName: string;
  routeType: number;
  color: string;
  textColor: string;
  mode: NetworkMode;
};
type SourceStop = {
  id: string;
  name: string;
  parentStation?: string;
  location: LonLat;
};

const INSERT_BATCH = 5_000;
const PATTERN_INSERT_BATCH = 1_000;
const TRANSIT_NETWORK_VERSION_KEY = 'transit:network:version';
const GTFS_FEED_HASH_KEY = 'gtfs:feed:sha256';

/**
 * Every file the import reads. Absent optional files still stamp the hash so
 * that adding transfers.txt to an otherwise identical feed counts as a change.
 */
const HASHED_FILES = [
  'routes.txt',
  'trips.txt',
  'shapes.txt',
  'stops.txt',
  'stop_times.txt',
  'transfers.txt',
  'calendar.txt',
  'calendar_dates.txt',
];

/**
 * Reads 1.5 GB before the import does anything else, so it announces each file:
 * a run that looks frozen on the very first minute is usually just hashing
 * stop_times.txt.
 */
async function hashGtfsFeed(gtfsPath: string): Promise<string> {
  const hash = createHash('sha256');
  for (const filename of HASHED_FILES) {
    logStep(`Hashing ${filename}`);
    const path = join(gtfsPath, filename);
    try {
      await access(path);
    } catch {
      hash.update(`${filename}:absent\n`);
      continue;
    }
    hash.update(`${filename}\n`);
    for await (const chunk of createReadStream(path)) {
      hash.update(chunk as Buffer);
    }
  }
  return hash.digest('hex');
}

/**
 * The source file is part of the message on purpose: `stop_times.txt` runs to
 * hundreds of thousands of rows, and "Missing stop_id in GTFS row" gives you
 * nothing to grep for.
 */
function required(row: CsvRow, key: string, source: string): string {
  const value = row[key];
  if (!value) {
    throw new Error(`Missing ${key} in ${source}: ${JSON.stringify(row).slice(0, 160)}`);
  }
  return value;
}

async function importTransitNetwork(gtfsPath: string) {
  for (const filename of ['routes.txt', 'trips.txt', 'shapes.txt', 'stops.txt', 'stop_times.txt']) {
    await access(join(gtfsPath, filename));
  }

  logStep('Reading routes.txt');
  const routes: ImportedRoute[] = [];
  for await (const row of readCsv(join(gtfsPath, 'routes.txt'))) {
    const routeType = Number(required(row, 'route_type', 'routes.txt'));
    const shortName = required(row, 'route_short_name', 'routes.txt');
    const mode = networkMode(routeType, shortName);
    if (!mode) continue;
    routes.push({
      id: required(row, 'route_id', 'routes.txt'),
      agencyId: required(row, 'agency_id', 'routes.txt'),
      shortName,
      longName: required(row, 'route_long_name', 'routes.txt'),
      routeType,
      // Genuinely optional in GTFS — a line without a brand colour is legal.
      color: row.route_color || '666666',
      textColor: row.route_text_color || 'FFFFFF',
      mode,
    });
  }
  if (routes.length === 0) {
    throw new Error('No metro, RER, Transilien, tram or bus route was found in routes.txt');
  }

  logStep(`Reading trips.txt for ${formatCount(routes.length)} lines`);
  const routeIds = new Set(routes.map((route) => route.id));
  const candidateByKey = new Map<string, PatternCandidate>();
  /** Every imported trip, for the GTFS fallback — patterns only keep representatives. */
  const scheduledTrips = new Map<string, ScheduledTrip>();
  for await (const trip of readCsv(join(gtfsPath, 'trips.txt'))) {
    const importedTrip = addScheduledTrip(scheduledTrips, routeIds, trip);
    if (!importedTrip) continue;

    const { id: tripId, routeId, directionId, shapeId, headsign } = importedTrip;
    const key = `${routeId}\u0000${directionId}\u0000${shapeId}\u0000${headsign}`;
    const current = candidateByKey.get(key);
    if (current) {
      current.tripCount += 1;
    } else {
      candidateByKey.set(key, {
        routeId,
        directionId,
        headsign,
        shapeId,
        representativeTripId: tripId,
        tripCount: 1,
      });
    }
  }

  const candidatesByRoute = Map.groupBy(
    [...candidateByKey.values()],
    (candidate) => candidate.routeId
  );
  const selections = routes.map((route) =>
    selectPatterns(candidatesByRoute.get(route.id) ?? [], route.id)
  );
  const patterns = selections.flatMap((selection) => selection.patterns);
  // Shape ids are pattern primary keys, so one route can never claim another's.
  const canonicalShapeIds = new Set(selections.map((selection) => selection.canonicalShapeId));

  const journeyShapeIds = new Set<string>();
  for (const trip of scheduledTrips.values()) journeyShapeIds.add(trip.shapeId);

  logStep(
    `Selected ${formatCount(patterns.length)} patterns from ` +
      `${formatCount(scheduledTrips.size)} trips; reading stops.txt`
  );
  const sourceStops = new Map<string, SourceStop>();
  for await (const stop of readCsv(join(gtfsPath, 'stops.txt'))) {
    const lon = Number(stop.stop_lon);
    const lat = Number(stop.stop_lat);
    if (!Number.isFinite(lon) || !Number.isFinite(lat)) continue;
    sourceStops.set(required(stop, 'stop_id', 'stops.txt'), {
      id: stop.stop_id,
      name: required(stop, 'stop_name', 'stops.txt'),
      parentStation: stop.parent_station || undefined,
      location: { lon, lat },
    });
  }

  /** Platforms collapse into their parent station, so lines meet on one shared stop. */
  function canonicalStopOf(stopId: string) {
    const stop = sourceStops.get(stopId);
    if (!stop) throw new Error(`Stop ${stopId} is missing from stops.txt`);
    const id = stop.parentStation ?? stop.id;
    return { id, stop: sourceStops.get(id) ?? stop };
  }

  const journeyStops = new Map<string, SourceStop>();
  for (const stop of sourceStops.values()) {
    const { id, stop: canonical } = canonicalStopOf(stop.id);
    journeyStops.set(id, canonical);
  }

  const transfersByKey = new Map<string, {
    fromStopId: string;
    toStopId: string;
    minTransferSeconds: number;
  }>();
  try {
    await access(join(gtfsPath, 'transfers.txt'));
    for await (const transfer of readCsv(join(gtfsPath, 'transfers.txt'))) {
      const fromStopId = canonicalStopOf(required(transfer, 'from_stop_id', 'transfers.txt')).id;
      const toStopId = canonicalStopOf(required(transfer, 'to_stop_id', 'transfers.txt')).id;
      if (fromStopId === toStopId) continue;
      const rawSeconds = Number(transfer.min_transfer_time);
      transfersByKey.set(`${fromStopId}\u0000${toStopId}`, {
        fromStopId,
        toStopId,
        minTransferSeconds: Number.isFinite(rawSeconds) && rawSeconds > 0 ? rawSeconds : 120,
      });
    }
  } catch {
    // transfers.txt is optional in GTFS; the planner still has station access walks.
  }

  const importedAt = new Date();
  logStep('Opening the network transaction');
  await db.transaction(async (tx) => {
    logStep('Truncating the tables this importer owns');
    /**
     * Replace exactly what this importer owns. TER, airport rail shuttles and
     * guided special modes remain untouched if another importer adds them later.
     *
     * TRUNCATE rather than DELETE: a full reload used to delete millions of
     * rows, and DELETE WAL-logs and leaves a dead tuple for every one of them —
     * each run wrote gigabytes of WAL and doubled the physical table size until
     * vacuum caught up. TRUNCATE resets the underlying files outright, is
     * transactional, and leaves nothing for autovacuum to chew on.
     */
    await tx.execute(sql`
      TRUNCATE ${transitServiceDates}, ${transitShapes}, ${transitTransfers},
        ${transitLineSchemaStops}, ${transitLineDirections},
        ${transitRoutePatternStops}, ${transitRoutePatterns},
        ${transitTrips}, ${transitProfileStops}, ${transitTimeProfiles},
        ${transitStopRoutes}
    `);
    await tx.delete(transitStopAliases);
    await tx.delete(transitRoutes).where(networkRouteCondition());

    /**
     * Stops are shared across modes, so they cannot be scoped by mode — only by
     * use. Whatever no pattern calls at any more is gone; whatever another mode
     * still serves stays. This also replaces the old delete-everything, which
     * only worked because metro was the sole mode.
     */
    await tx.execute(sql`
      DELETE FROM ${transitStops} AS stops
      WHERE NOT EXISTS (
        SELECT 1 FROM ${transitRoutePatternStops} AS pattern_stops
        WHERE pattern_stops.stop_id = stops.id
      )
    `);

    logStep(`Inserting ${formatCount(routes.length)} routes and ${formatCount(journeyStops.size)} stops`);
    await tx.insert(transitRoutes).values(
      routes.map(({ mode: _, ...route }) => ({ ...route, importedAt }))
    );

    /**
     * Upsert rather than insert: a station this mode serves may also be served by
     * another one, in which case the delete above rightly spared it.
     */
    const stopValues = [...journeyStops].map(([id, stop]) => ({
      id,
      name: stop.name,
      location: stop.location,
    }));
    const stopKeyById = new Map<string, number>();
    for (let start = 0; start < stopValues.length; start += INSERT_BATCH) {
      const inserted = await tx
        .insert(transitStops)
        .values(stopValues.slice(start, start + INSERT_BATCH))
        .onConflictDoUpdate({
          target: transitStops.id,
          set: { name: sql`excluded.name`, location: sql`excluded.location` },
        })
        .returning({ id: transitStops.id, numericId: transitStops.numericId });
      for (const stop of inserted) stopKeyById.set(stop.id, stop.numericId);
    }

    const aliasBySourceId = new Map<string, { sourceId: string; stopId: string }>();
    for (const stop of sourceStops.values()) {
      const stopId = canonicalStopOf(stop.id).id;
      for (const sourceId of [stop.id, `stop_point:${stop.id}`, `stop_area:${stopId}`]) {
        aliasBySourceId.set(sourceId, { sourceId, stopId });
      }
    }
    const aliasValues = [...aliasBySourceId.values()];
    for (let start = 0; start < aliasValues.length; start += INSERT_BATCH) {
      await tx.insert(transitStopAliases).values(aliasValues.slice(start, start + INSERT_BATCH));
    }

    logStep(`Inserting ${formatCount(patterns.length)} route patterns`);
    const patternValues = patterns.map((pattern) => ({
        id: pattern.shapeId,
        routeId: pattern.routeId,
        directionId: pattern.directionId,
        headsign: pattern.headsign,
        tripCount: pattern.tripCount,
        isCanonical: canonicalShapeIds.has(pattern.shapeId),
        geometry: null,
      }));
    for (let start = 0; start < patternValues.length; start += PATTERN_INSERT_BATCH) {
      await tx
        .insert(transitRoutePatterns)
        .values(patternValues.slice(start, start + PATTERN_INSERT_BATCH));
    }

    logStep(`Streaming shapes.txt for ${formatCount(journeyShapeIds.size)} shapes`);
    await importShapes({ gtfsPath, tx, shapeIds: journeyShapeIds, readCsv });
    logStep('Attaching shape geometry to rail patterns');
    await tx.execute(sql`
      UPDATE ${transitRoutePatterns} AS patterns
      SET geometry = shapes.geometry
      FROM ${transitShapes} AS shapes, ${transitRoutes} AS routes
      WHERE patterns.id = shapes.id
        AND routes.id = patterns.route_id
        AND routes.route_type <> ${ROUTE_TYPE.bus}
    `);

    const transfers = [...transfersByKey.values()];
    logStep(`Inserting ${formatCount(transfers.length)} transfers`);
    for (let start = 0; start < transfers.length; start += INSERT_BATCH) {
      await tx
        .insert(transitTransfers)
        .values(transfers.slice(start, start + INSERT_BATCH))
        .onConflictDoUpdate({
          target: [transitTransfers.fromStopId, transitTransfers.toStopId],
          set: { minTransferSeconds: sql`excluded.min_transfer_seconds` },
        });
    }

    /**
     * Same transaction as the network on purpose: the route delete above just
     * cascaded the previous theoretical departures away, so schedules must
     * come back before the commit or a crash would leave the fallback empty.
     */
    await importSchedules({
      gtfsPath,
      tx,
      trips: scheduledTrips,
      canonicalStopIdOf: (stopId) => canonicalStopOf(stopId).id,
      stopKeyById,
      representativeTrips: new Map(
        patterns.map((pattern) => [
          pattern.shapeId,
          scheduledTrips.get(pattern.representativeTripId)!.numericId,
        ])
      ),
      readCsv,
      readPositionalCsv,
    });

    logStep('Committing the network transaction');
  });

  const counts = Map.groupBy(routes, (route) => route.mode);
  logStep(
    `Imported ${counts.get('metro')?.length ?? 0} metro, ` +
      `${counts.get('rer')?.length ?? 0} RER, ` +
      `${counts.get('transilien')?.length ?? 0} Transilien, ` +
      `${counts.get('tram')?.length ?? 0} tram and ` +
      `${counts.get('bus')?.length ?? 0} bus lines, ` +
      `${patterns.length} representative patterns, ${journeyStops.size} shared stops.`
  );
}

/**
 * Derived data runs after the network commit: every step is a pure function of
 * the committed base tables, idempotent and re-runnable. Keeping them out of
 * the bulk transaction keeps its lock window short and lets each step's memory
 * spike happen alone. Until this finishes, patterns briefly lack drawn
 * geometry — a degraded map, never broken schedules.
 */
async function deriveNetworkData() {
  await step('Projecting stops onto patterns', () => db.execute(projectStopsOntoPatterns()));
  await step('Computing drawn geometry', () => db.execute(computeDrawnGeometry()));

  logStep('Building line schemas');
  await importLineSchemasFromDatabase();
}

/**
 * Fresh planner statistics right after the reload; with TRUNCATE there are no
 * dead tuples, so this is cheap. VACUUM cannot run inside a transaction, hence
 * the raw client.
 */
async function vacuumAnalyzeTransitTables() {
  await client.unsafe(`
    VACUUM ANALYZE transit_routes, transit_stops, transit_route_patterns,
      transit_route_pattern_stops, transit_trips, transit_time_profiles,
      transit_profile_stops, transit_service_dates, transit_stop_routes,
      transit_transfers, transit_shapes, transit_line_directions,
      transit_line_schema_stops
  `);
}

/** Move API station metadata to a fresh Redis namespace after a successful import. */
async function bumpTransitNetworkCacheVersion() {
  const redisURL = process.env.REDIS_URL;
  if (!redisURL) return;

  const redis = new BunRedisClient(redisURL);
  try {
    await redis.incr(TRANSIT_NETWORK_VERSION_KEY);
  } catch (cause) {
    // A Redis outage must not turn a committed GTFS import into a failed import.
    console.error(`[worker] could not bump transit cache version`, cause);
  } finally {
    redis.close();
  }
}

const args = process.argv.slice(2);
const force = args.includes('--force');
const gtfsPath = args.find((arg) => !arg.startsWith('--')) ?? process.env.GTFS_PATH;
if (!gtfsPath) {
  throw new Error('Pass the extracted GTFS directory as an argument or set GTFS_PATH');
}

const importStartedAt = performance.now();
async function refreshAccessibilityData() {
  await step('Refreshing IDFM station accessibility', async () => {
    try {
      const result = await refreshAccessibilitySnapshot();
      logStep(
        `Imported ${formatCount(result.imported)} accessibility rows ` +
          `(source ${result.sourceUpdatedAt ?? 'date inconnue'}).`
      );
    } catch (cause) {
      // Accessibility is a derived snapshot. A source outage must not erase the
      // last valid declaration or make a complete GTFS import fail.
      console.error('[worker] accessibility snapshot unchanged', cause);
    }
  });
}

async function refreshWayfindingData() {
  await step('Refreshing IDFM station exits and boarding positions', async () => {
    try {
      const result = await refreshWayfindingSnapshot();
      logStep(
        `Imported ${formatCount(result.exits)} station exits ` +
          `(source ${result.exitsUpdatedAt ?? 'date inconnue'}) and ` +
          `${formatCount(result.positions)} boarding positions ` +
          `(source ${result.positionsUpdatedAt ?? 'date inconnue'}).`
      );
    } catch (cause) {
      // Same rule as accessibility: a snapshot of someone else's referential
      // never gets to fail a completed network import.
      console.error('[worker] wayfinding snapshot unchanged', cause);
    }
  });
}

try {
  logStep(`Importing ${gtfsPath}`);
  const feedHash = await hashGtfsFeed(gtfsPath);
  const [stored] = await db
    .select()
    .from(importMeta)
    .where(eq(importMeta.key, GTFS_FEED_HASH_KEY));
  if (!force && stored?.value === feedHash) {
    console.log('GTFS feed unchanged since the last completed import — nothing to do (--force to reimport).');
  } else {
    await importTransitNetwork(gtfsPath);
    await deriveNetworkData();
    await step('Vacuuming and analyzing the transit tables', vacuumAnalyzeTransitTables);
    /**
     * Only a fully completed import records its hash: a crash in any phase
     * above leaves the previous value, so the next run redoes everything.
     */
    await db
      .insert(importMeta)
      .values({ key: GTFS_FEED_HASH_KEY, value: feedHash })
      .onConflictDoUpdate({
        target: importMeta.key,
        set: { value: feedHash, updatedAt: new Date() },
      });
    await bumpTransitNetworkCacheVersion();
    logStep(`Import complete in ${formatDuration(performance.now() - importStartedAt)}.`);
  }
  await refreshAccessibilityData();
  // After the network: exits hang off `transit_stops` and boarding positions off
  // `transit_stop_aliases`, both written by the import above.
  await refreshWayfindingData();
} finally {
  await client.end();
}
