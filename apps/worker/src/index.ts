import { createReadStream } from 'node:fs';
import { access } from 'node:fs/promises';
import { join } from 'node:path';

import { client, db } from '@via/db';
import {
  ROUTE_TYPE,
  isMode,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
  type LonLat,
  type TransitMode,
} from '@via/db/schema';
import { projectStopsOntoPatterns } from '@via/db/projection';
import { parse } from 'csv-parse';
import { eq, sql } from 'drizzle-orm';

import { selectPatterns, type PatternCandidate } from './pattern-selection';

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
};
type SourceStop = {
  id: string;
  name: string;
  parentStation?: string;
  location: LonLat;
};

/** The mode this importer owns. Everything it deletes and inserts is scoped to it. */
const IMPORTED_MODE = 'metro' satisfies TransitMode;

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

async function importMetroNetwork(gtfsPath: string) {
  for (const filename of ['routes.txt', 'trips.txt', 'shapes.txt', 'stops.txt', 'stop_times.txt']) {
    await access(join(gtfsPath, filename));
  }

  const routes: ImportedRoute[] = [];
  for await (const row of readCsv(join(gtfsPath, 'routes.txt'))) {
    if (!isMode(row.route_type, IMPORTED_MODE)) continue;
    routes.push({
      id: required(row, 'route_id', 'routes.txt'),
      agencyId: required(row, 'agency_id', 'routes.txt'),
      shortName: required(row, 'route_short_name', 'routes.txt'),
      longName: required(row, 'route_long_name', 'routes.txt'),
      routeType: Number(required(row, 'route_type', 'routes.txt')),
      // Genuinely optional in GTFS — a line without a brand colour is legal.
      color: row.route_color || '666666',
      textColor: row.route_text_color || 'FFFFFF',
    });
  }
  if (routes.length === 0) throw new Error(`No ${IMPORTED_MODE} route was found in routes.txt`);

  const routeIds = new Set(routes.map((route) => route.id));
  const candidateByKey = new Map<string, PatternCandidate>();
  for await (const trip of readCsv(join(gtfsPath, 'trips.txt'))) {
    if (!routeIds.has(trip.route_id)) continue;
    const directionId = Number(required(trip, 'direction_id', 'trips.txt'));
    const shapeId = required(trip, 'shape_id', 'trips.txt');
    const headsign = required(trip, 'trip_headsign', 'trips.txt');
    const key = `${trip.route_id}\u0000${directionId}\u0000${shapeId}\u0000${headsign}`;
    const current = candidateByKey.get(key);
    if (current) {
      current.tripCount += 1;
    } else {
      candidateByKey.set(key, {
        routeId: trip.route_id,
        directionId,
        headsign,
        shapeId,
        representativeTripId: required(trip, 'trip_id', 'trips.txt'),
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

  const coordinatesByShape = new Map<string, Array<LonLat & { sequence: number }>>(
    patterns.map((pattern) => [pattern.shapeId, []])
  );
  for await (const point of readCsv(join(gtfsPath, 'shapes.txt'))) {
    const coordinates = coordinatesByShape.get(point.shape_id);
    if (!coordinates) continue;
    coordinates.push({
      lat: Number(required(point, 'shape_pt_lat', 'shapes.txt')),
      lon: Number(required(point, 'shape_pt_lon', 'shapes.txt')),
      sequence: Number(required(point, 'shape_pt_sequence', 'shapes.txt')),
    });
  }
  for (const [shapeId, coordinates] of coordinatesByShape) {
    coordinates.sort((a, b) => a.sequence - b.sequence);
    if (coordinates.length < 2) throw new Error(`Shape ${shapeId} is empty`);
  }

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

  const patternByTrip = new Map(
    patterns.map((pattern) => [pattern.representativeTripId, pattern])
  );
  const canonicalStops = new Map<string, SourceStop>();
  const stopsByShape = new Map<string, Array<{ stopId: string; sequence: number }>>(
    patterns.map((pattern) => [pattern.shapeId, []])
  );
  for await (const stopTime of readCsv(join(gtfsPath, 'stop_times.txt'))) {
    const pattern = patternByTrip.get(stopTime.trip_id);
    if (!pattern) continue;
    const { id, stop } = canonicalStopOf(required(stopTime, 'stop_id', 'stop_times.txt'));
    canonicalStops.set(id, stop);
    stopsByShape.get(pattern.shapeId)!.push({
      stopId: id,
      sequence: Number(required(stopTime, 'stop_sequence', 'stop_times.txt')),
    });
  }
  // Two platforms of one station in a row collapse into a single call.
  for (const [shapeId, sequence] of stopsByShape) {
    sequence.sort((a, b) => a.sequence - b.sequence);
    stopsByShape.set(
      shapeId,
      sequence.filter((stop, index) => stop.stopId !== sequence[index - 1]?.stopId)
    );
  }

  const importedAt = new Date();
  await db.transaction(async (tx) => {
    /**
     * Scoped to the mode being imported. An unscoped `DELETE FROM transit_routes`
     * reads as "start fresh" and is harmless while metro is all there is — but
     * the day the bus network is imported, running the metro importer would wipe
     * it. Patterns and pattern-stops follow through the cascade.
     */
    await tx.delete(transitRoutes).where(eq(transitRoutes.routeType, ROUTE_TYPE[IMPORTED_MODE]));

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

    await tx.insert(transitRoutes).values(routes.map((route) => ({ ...route, importedAt })));

    /**
     * Upsert rather than insert: a station this mode serves may also be served by
     * another one, in which case the delete above rightly spared it.
     */
    await tx
      .insert(transitStops)
      .values(
        [...canonicalStops].map(([id, stop]) => ({
          id,
          name: stop.name,
          location: stop.location,
        }))
      )
      .onConflictDoUpdate({
        target: transitStops.id,
        set: { name: sql`excluded.name`, location: sql`excluded.location` },
      });

    for (const pattern of patterns) {
      await tx.insert(transitRoutePatterns).values({
        id: pattern.shapeId,
        routeId: pattern.routeId,
        directionId: pattern.directionId,
        headsign: pattern.headsign,
        tripCount: pattern.tripCount,
        isCanonical: canonicalShapeIds.has(pattern.shapeId),
        geometry: coordinatesByShape
          .get(pattern.shapeId)!
          .map(({ lon, lat }) => ({ lon, lat })),
      });

      const patternStops = stopsByShape.get(pattern.shapeId)!;
      if (patternStops.length === 0) throw new Error(`Pattern ${pattern.shapeId} has no stops`);
      await tx.insert(transitRoutePatternStops).values(
        patternStops.map(({ stopId, sequence }) => ({
          patternId: pattern.shapeId,
          stopId,
          stopSequence: sequence,
        }))
      );
    }

    await tx.execute(projectStopsOntoPatterns());
  });

  const routesByStop = new Map<string, Set<string>>();
  for (const pattern of patterns) {
    for (const { stopId } of stopsByShape.get(pattern.shapeId)!) {
      const servedRoutes = routesByStop.get(stopId) ?? new Set<string>();
      servedRoutes.add(pattern.routeId);
      routesByStop.set(stopId, servedRoutes);
    }
  }
  const interchangeCount = [...routesByStop.values()].filter((routeSet) => routeSet.size > 1).length;

  console.log(
    `Imported ${routes.length} metro lines, ${patterns.length} representative branches, ` +
      `${canonicalStops.size} shared stations and ${interchangeCount} interchanges.`
  );
}

const gtfsPath = process.argv[2] ?? process.env.GTFS_PATH;
if (!gtfsPath) {
  throw new Error('Pass the extracted GTFS directory as an argument or set GTFS_PATH');
}

try {
  await importMetroNetwork(gtfsPath);
} finally {
  await client.end();
}
