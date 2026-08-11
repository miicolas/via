import { createReadStream } from 'node:fs';
import { access } from 'node:fs/promises';
import { join } from 'node:path';

import {
  client,
  db,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
  type LonLat,
} from '@via/db';
import { parse } from 'csv-parse';
import { sql } from 'drizzle-orm';

import { selectPatterns, type PatternCandidate } from './pattern-selection';

type CsvRow = Record<string, string>;
type RouteRow = CsvRow & {
  route_id: string;
  agency_id: string;
  route_short_name: string;
  route_long_name: string;
  route_type: string;
  route_color: string;
  route_text_color: string;
};
type SourceStop = {
  id: string;
  name: string;
  parentStation?: string;
  location: LonLat;
};

const METRO_ROUTE_TYPE = '1';

async function* readCsv(path: string): AsyncGenerator<CsvRow> {
  const parser = createReadStream(path).pipe(
    parse({ bom: true, columns: true, skip_empty_lines: true })
  );

  for await (const row of parser) {
    yield row as CsvRow;
  }
}

function required(row: CsvRow, key: string): string {
  const value = row[key];
  if (!value) throw new Error(`Missing ${key} in GTFS row`);
  return value;
}

async function importMetroNetwork(gtfsPath: string) {
  for (const filename of ['routes.txt', 'trips.txt', 'shapes.txt', 'stops.txt', 'stop_times.txt']) {
    await access(join(gtfsPath, filename));
  }

  const routes: RouteRow[] = [];
  for await (const row of readCsv(join(gtfsPath, 'routes.txt'))) {
    if (row.route_type === METRO_ROUTE_TYPE) routes.push(row as RouteRow);
  }
  if (routes.length === 0) throw new Error('No metro route was found in routes.txt');

  const routeIds = new Set(routes.map((route) => route.route_id));
  const candidateByKey = new Map<string, PatternCandidate>();
  for await (const trip of readCsv(join(gtfsPath, 'trips.txt'))) {
    if (!routeIds.has(trip.route_id)) continue;
    const directionId = Number(required(trip, 'direction_id'));
    const shapeId = required(trip, 'shape_id');
    const headsign = required(trip, 'trip_headsign');
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
        representativeTripId: required(trip, 'trip_id'),
        tripCount: 1,
      });
    }
  }

  const candidatesByRoute = Map.groupBy(
    [...candidateByKey.values()],
    (candidate) => candidate.routeId
  );
  const selections = routes.map((route) =>
    selectPatterns(candidatesByRoute.get(route.route_id) ?? [], route.route_id)
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
      lat: Number(required(point, 'shape_pt_lat')),
      lon: Number(required(point, 'shape_pt_lon')),
      sequence: Number(required(point, 'shape_pt_sequence')),
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
    sourceStops.set(required(stop, 'stop_id'), {
      id: stop.stop_id,
      name: required(stop, 'stop_name'),
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
    const { id, stop } = canonicalStopOf(required(stopTime, 'stop_id'));
    canonicalStops.set(id, stop);
    stopsByShape.get(pattern.shapeId)!.push({
      stopId: id,
      sequence: Number(required(stopTime, 'stop_sequence')),
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
    await tx.delete(transitRoutes);
    await tx.delete(transitStops);

    await tx.insert(transitRoutes).values(
      routes.map((route) => ({
        id: route.route_id,
        agencyId: route.agency_id,
        shortName: route.route_short_name,
        longName: route.route_long_name,
        routeType: Number(route.route_type),
        color: route.route_color || '666666',
        textColor: route.route_text_color || 'FFFFFF',
        importedAt,
      }))
    );

    await tx.insert(transitStops).values(
      [...canonicalStops].map(([id, stop]) => ({
        id,
        name: stop.name,
        location: stop.location,
      }))
    );

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

    /**
     * Project every stop onto the track of the pattern that serves it.
     *
     * This is the one thing the map needs that GTFS does not provide: stops are
     * recorded at their street entrance, so drawn as-is they float beside the
     * line instead of sitting on it. The API used to compute the projection on
     * every request; it only ever changes here, so it is computed here.
     *
     * A single UPDATE rather than a value on INSERT because it depends on a join,
     * which neither an INSERT nor a Postgres generated column can express.
     */
    await tx.execute(sql`
      UPDATE ${transitRoutePatternStops} AS prs
      SET snapped_location = ST_ClosestPoint(p.geometry, s.location),
          snap_distance_m  = ST_Distance(p.geometry::geography, s.location::geography)
      FROM ${transitRoutePatterns} AS p, ${transitStops} AS s
      WHERE prs.pattern_id = p.id AND prs.stop_id = s.id
    `);
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
