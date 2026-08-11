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
import { eq, sql } from 'drizzle-orm';

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
type Pattern = {
  directionId: number;
  headsign: string;
  shapeId: string;
  representativeTripId: string;
  tripCount: number;
};

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

async function importLineOne(gtfsPath: string) {
  for (const filename of ['routes.txt', 'trips.txt', 'shapes.txt', 'stops.txt', 'stop_times.txt']) {
    await access(join(gtfsPath, filename));
  }

  let route: RouteRow | undefined;
  for await (const row of readCsv(join(gtfsPath, 'routes.txt'))) {
    if (row.route_type === '1' && row.route_short_name.trim() === '1') {
      if (route) throw new Error('More than one metro route named 1 was found');
      route = row as RouteRow;
    }
  }
  if (!route) throw new Error('Metro line 1 was not found in routes.txt');

  const patternCounts = new Map<string, Pattern>();
  for await (const trip of readCsv(join(gtfsPath, 'trips.txt'))) {
    if (trip.route_id !== route.route_id) continue;
    const directionId = Number(required(trip, 'direction_id'));
    const shapeId = required(trip, 'shape_id');
    const headsign = required(trip, 'trip_headsign');
    const key = `${directionId}\u0000${shapeId}\u0000${headsign}`;
    const current = patternCounts.get(key);
    if (current) {
      current.tripCount += 1;
    } else {
      patternCounts.set(key, {
        directionId,
        shapeId,
        headsign,
        representativeTripId: required(trip, 'trip_id'),
        tripCount: 1,
      });
    }
  }

  const patterns = [0, 1].map((directionId) => {
    const candidates = [...patternCounts.values()].filter(
      (pattern) => pattern.directionId === directionId
    );
    const primary = candidates.sort((a, b) => b.tripCount - a.tripCount)[0];
    if (!primary) throw new Error(`No primary pattern found for direction ${directionId}`);
    return primary;
  });
  const canonical = [...patterns].sort((a, b) => b.tripCount - a.tripCount)[0]!;

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
  for (const coordinates of coordinatesByShape.values()) {
    coordinates.sort((a, b) => a.sequence - b.sequence);
  }

  const patternByTrip = new Map(
    patterns.map((pattern) => [pattern.representativeTripId, pattern])
  );
  const stopSequenceByShape = new Map<string, Array<{ stopId: string; sequence: number }>>(
    patterns.map((pattern) => [pattern.shapeId, []])
  );
  for await (const stopTime of readCsv(join(gtfsPath, 'stop_times.txt'))) {
    const pattern = patternByTrip.get(stopTime.trip_id);
    if (!pattern) continue;
    stopSequenceByShape.get(pattern.shapeId)!.push({
      stopId: required(stopTime, 'stop_id'),
      sequence: Number(required(stopTime, 'stop_sequence')),
    });
  }
  for (const sequence of stopSequenceByShape.values()) {
    sequence.sort((a, b) => a.sequence - b.sequence);
  }

  const wantedStopIds = new Set(
    [...stopSequenceByShape.values()].flatMap((sequence) => sequence.map(({ stopId }) => stopId))
  );
  const stopRows: Array<{ id: string; name: string; location: LonLat }> = [];
  for await (const stop of readCsv(join(gtfsPath, 'stops.txt'))) {
    if (!wantedStopIds.has(stop.stop_id)) continue;
    stopRows.push({
      id: required(stop, 'stop_id'),
      name: required(stop, 'stop_name'),
      location: {
        lon: Number(required(stop, 'stop_lon')),
        lat: Number(required(stop, 'stop_lat')),
      },
    });
  }

  if (stopRows.length !== wantedStopIds.size) {
    throw new Error(`Found ${stopRows.length} of ${wantedStopIds.size} required stops`);
  }

  await db.transaction(async (tx) => {
    await tx
      .insert(transitRoutes)
      .values({
        id: route.route_id,
        agencyId: route.agency_id,
        shortName: route.route_short_name,
        longName: route.route_long_name,
        routeType: Number(route.route_type),
        color: route.route_color || 'FFBE00',
        textColor: route.route_text_color || '000000',
        importedAt: new Date(),
      })
      .onConflictDoUpdate({
        target: transitRoutes.id,
        set: {
          agencyId: route.agency_id,
          shortName: route.route_short_name,
          longName: route.route_long_name,
          routeType: Number(route.route_type),
          color: route.route_color || 'FFBE00',
          textColor: route.route_text_color || '000000',
          importedAt: new Date(),
        },
      });

    await tx.delete(transitRoutePatterns).where(eq(transitRoutePatterns.routeId, route.route_id));
    await tx
      .insert(transitStops)
      .values(stopRows)
      .onConflictDoUpdate({
        target: transitStops.id,
        set: {
          name: sql`excluded.name`,
          location: sql`excluded.location`,
        },
      });

    for (const pattern of patterns) {
      const coordinates = coordinatesByShape.get(pattern.shapeId)!;
      if (coordinates.length < 2) throw new Error(`Shape ${pattern.shapeId} is empty`);
      await tx.insert(transitRoutePatterns).values({
        id: pattern.shapeId,
        routeId: route.route_id,
        directionId: pattern.directionId,
        headsign: pattern.headsign,
        tripCount: pattern.tripCount,
        isCanonical: pattern.shapeId === canonical.shapeId,
        geometry: coordinates.map(({ lon, lat }) => ({ lon, lat })),
      });
      await tx.insert(transitRoutePatternStops).values(
        stopSequenceByShape.get(pattern.shapeId)!.map(({ stopId, sequence }) => ({
          patternId: pattern.shapeId,
          stopId,
          stopSequence: sequence,
        }))
      );
    }
  });

  console.log(
    `Imported metro ${route.route_short_name}: ${patterns.length} directions, ` +
      `${coordinatesByShape.get(canonical.shapeId)!.length} points on the canonical line, ` +
      `${stopSequenceByShape.get(canonical.shapeId)!.length} stations.`
  );
}

const gtfsPath = process.argv[2] ?? process.env.GTFS_PATH;
if (!gtfsPath) {
  throw new Error('Pass the extracted GTFS directory as an argument or set GTFS_PATH');
}

try {
  await importLineOne(gtfsPath);
} finally {
  await client.end();
}
