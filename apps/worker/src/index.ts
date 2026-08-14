import { createReadStream } from 'node:fs';
import { access } from 'node:fs/promises';
import { join } from 'node:path';

import { client, db } from '@via/db';
import {
  RER_SHORT_NAMES,
  ROUTE_TYPE,
  networkMode,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitShapes,
  transitServiceDates,
  transitStopRoutes,
  transitStops,
  transitTrips,
  transitTransfers,
  type LonLat,
  type NetworkMode,
} from '@via/db/schema';
import { computeDrawnGeometry } from '@via/db/drawn-geometry';
import { projectStopsOntoPatterns } from '@via/db/projection';
import { parse } from 'csv-parse';
import { and, eq, inArray, or, sql } from 'drizzle-orm';

import { selectPatterns, type PatternCandidate } from './pattern-selection';
import { importSchedules, type ScheduledTrip } from './schedule/import-schedules';
import { addScheduledTrip } from './schedule/scheduled-trips';
import { importShapes } from './shapes/import-shapes';

type CsvRow = Record<string, string>;
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

async function* readCsv(path: string): AsyncGenerator<CsvRow> {
  const parser = createReadStream(path).pipe(
    parse({ bom: true, columns: true, skip_empty_lines: true })
  );

  for await (const row of parser) {
    yield row as CsvRow;
  }
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
  if (routes.length === 0) throw new Error('No metro, RER or bus route was found in routes.txt');

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

  const journeyShapeIds = new Set([...scheduledTrips.values()].map((trip) => trip.shapeId));

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
  await db.transaction(async (tx) => {
    /**
     * Replace exactly what this importer owns. Other rail (Transilien and TER)
     * remains untouched if another importer adds it later.
     */
    await tx.delete(transitServiceDates);
    await tx.delete(transitShapes);
    await tx.delete(transitTransfers);
    await tx.delete(transitRoutePatternStops);
    await tx.delete(transitRoutePatterns);
    await tx.delete(transitTrips);
    await tx.delete(transitStopRoutes);
    await tx
      .delete(transitRoutes)
      .where(
        or(
          eq(transitRoutes.routeType, ROUTE_TYPE.metro),
          eq(transitRoutes.routeType, ROUTE_TYPE.bus),
          and(
            eq(transitRoutes.routeType, ROUTE_TYPE.rail),
            inArray(transitRoutes.shortName, RER_SHORT_NAMES)
          )
        )
      );

    /**
     * Stops are shared across modes, so they cannot be scoped by mode — only by
     * use. Whatever no pattern calls at any more is gone; whatever another mode
     * still serves stays. This also replaces the old delete-everything, which
     * only worked because metro was the sole mode.
     */
    await tx.execute(sql`
      DELETE FROM ${transitStops}
      WHERE id NOT IN (SELECT stop_id FROM ${transitRoutePatternStops})
    `);

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

    await importShapes({ gtfsPath, tx, shapeIds: journeyShapeIds, readCsv });
    await tx.execute(sql`
      UPDATE ${transitRoutePatterns} AS patterns
      SET geometry = shapes.geometry
      FROM ${transitShapes} AS shapes, ${transitRoutes} AS routes
      WHERE patterns.id = shapes.id
        AND routes.id = patterns.route_id
        AND routes.route_type <> ${ROUTE_TYPE.bus}
    `);

    const transfers = [...transfersByKey.values()];
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
    });

    await tx.execute(projectStopsOntoPatterns());
    await tx.execute(computeDrawnGeometry());
    await tx.execute(sql`ANALYZE ${transitRoutePatterns}`);
    await tx.execute(sql`ANALYZE ${transitStops}`);
    await tx.execute(sql`ANALYZE ${transitStopRoutes}`);
    await tx.execute(sql`ANALYZE ${transitTransfers}`);
  });

  const counts = Map.groupBy(routes, (route) => route.mode);
  console.log(
    `Imported ${counts.get('metro')?.length ?? 0} metro, ` +
      `${counts.get('rer')?.length ?? 0} RER and ${counts.get('bus')?.length ?? 0} bus lines, ` +
      `${patterns.length} representative patterns, ${journeyStops.size} shared stops.`
  );
}

const gtfsPath = process.argv[2] ?? process.env.GTFS_PATH;
if (!gtfsPath) {
  throw new Error('Pass the extracted GTFS directory as an argument or set GTFS_PATH');
}

try {
  await importTransitNetwork(gtfsPath);
} finally {
  await client.end();
}
