import { db } from '@via/db';
import {
  boardingPositions,
  stationExits,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitStopAliases,
  transitStops,
  type LonLat,
} from '@via/db/schema';
import { asc, eq, inArray } from 'drizzle-orm';

import {
  datasetUpdatedAt,
  exportDataset,
  readQuayStopAreas,
  readStopAreaParents,
  viaId,
} from '../idfm/referential';
import { mapBoardingPositions, mapExits, stationRouteKey } from './map-wayfinding';
import { metersEastNorth, type TravelVector } from './quay-directions';

const INSERT_BATCH = 500;

/**
 * Imports the station exits and the carriage advice that goes with them.
 *
 * Must run after a GTFS import: exits attach to `transit_stops`, every exact or
 * direction-safe aggregate boarding position is validated against
 * `transit_stop_aliases`, and the direction of RER quays is inferred against
 * the route patterns. On an empty network it throws rather than committing a
 * snapshot that silently matches nothing.
 */
export async function refreshWayfindingSnapshot() {
  const { exitRows, positions, exitsUpdatedAt, positionsUpdatedAt } =
    await buildWayfindingSnapshot();

  const importedAt = new Date();
  await db.transaction(async (tx) => {
    // Positions first: they reference the exits about to be replaced.
    await tx.delete(boardingPositions);
    await tx.delete(stationExits);

    for (let start = 0; start < exitRows.length; start += INSERT_BATCH) {
      await tx.insert(stationExits).values(
        exitRows
          .slice(start, start + INSERT_BATCH)
          .map((row) => ({ ...row, sourceUpdatedAt: exitsUpdatedAt, importedAt }))
      );
    }
    for (let start = 0; start < positions.length; start += INSERT_BATCH) {
      await tx.insert(boardingPositions).values(
        positions
          .slice(start, start + INSERT_BATCH)
          .map((row) => ({ ...row, sourceUpdatedAt: positionsUpdatedAt, importedAt }))
      );
    }
  });

  return {
    exits: exitRows.length,
    positions: positions.length,
    exitsUpdatedAt: exitsUpdatedAt?.toISOString(),
    positionsUpdatedAt: positionsUpdatedAt?.toISOString(),
  };
}

/** Everything the import would write, computed without touching the tables. */
export async function buildWayfindingSnapshot() {
  const [
    accesses,
    accessRelations,
    quays,
    stopAreas,
    trainPositions,
    exitsUpdatedAt,
    positionsUpdatedAt,
  ] = await Promise.all([
    exportDataset('accesses'),
    exportDataset('accessRelations'),
    exportDataset('quays'),
    exportDataset('stopAreas'),
    exportDataset('trainPositions'),
    datasetUpdatedAt('accesses'),
    datasetUpdatedAt('trainPositions'),
  ]);

  const [stops, aliases] = await Promise.all([
    db.select({ id: transitStops.id }).from(transitStops),
    db.select({ sourceId: transitStopAliases.sourceId }).from(transitStopAliases),
  ]);

  const knownStopIDs = new Set(stops.map((stop) => stop.id));
  const stopAreaParents = readStopAreaParents(stopAreas);
  const exits = mapExits({
    accesses,
    accessRelations,
    stopAreaParents,
    knownStopIDs,
  });
  if (exits.size === 0) throw new Error('No station exit matches the transit network');

  const stationByStopArea = new Map<string, string>();
  for (const [stopAreaId, parentId] of stopAreaParents) {
    const stationStopId = viaId(parentId);
    if (knownStopIDs.has(stationStopId)) stationByStopArea.set(stopAreaId, stationStopId);
  }

  const { stationLocationByStopId, travelVectorsByStationRoute } =
    await readDirectionContext(trainPositions);

  const positions = mapBoardingPositions({
    trainPositions,
    exitIDs: new Set(exits.keys()),
    knownQuayIDs: new Set(aliases.map((alias) => alias.sourceId)),
    stopAreaByQuay: readQuayStopAreas(quays),
    stationByStopArea,
    exitLocationById: new Map(
      [...exits.values()].map((exit) => [exit.id, exit.location])
    ),
    stationLocationByStopId,
    travelVectorsByStationRoute,
  });

  return { exitRows: [...exits.values()], positions, exitsUpdatedAt, positionsUpdatedAt };
}

/**
 * The travel direction of every route the advice mentions, at every station:
 * a unit vector from each station towards the next call of a pattern of that
 * direction. The nearest next call wins — a semi-direct mission's vector leaps
 * over skipped stations, which bends it on curved track.
 */
async function readDirectionContext(trainPositions: Record<string, unknown>[]) {
  const routeIDs = [
    ...new Set(
      trainPositions.flatMap((row) => {
        const lineID = row.line_id;
        return typeof lineID === 'string' || typeof lineID === 'number'
          ? [viaId(String(lineID))]
          : [];
      })
    ),
  ];

  const stationLocationByStopId = new Map<string, LonLat>();
  const travelVectorsByStationRoute = new Map<string, TravelVector[]>();
  if (routeIDs.length === 0) return { stationLocationByStopId, travelVectorsByStationRoute };

  const calls = await db
    .select({
      patternId: transitRoutePatternStops.patternId,
      routeId: transitRoutePatterns.routeId,
      directionId: transitRoutePatterns.directionId,
      stopId: transitRoutePatternStops.stopId,
      location: transitStops.location,
    })
    .from(transitRoutePatternStops)
    .innerJoin(
      transitRoutePatterns,
      eq(transitRoutePatterns.id, transitRoutePatternStops.patternId)
    )
    .innerJoin(transitStops, eq(transitStops.id, transitRoutePatternStops.stopId))
    .where(inArray(transitRoutePatterns.routeId, routeIDs))
    .orderBy(
      asc(transitRoutePatternStops.patternId),
      asc(transitRoutePatternStops.stopSequence)
    );

  const bestHopMeters = new Map<string, number>();
  for (const [index, call] of calls.entries()) {
    stationLocationByStopId.set(call.stopId, call.location);

    const next = calls[index + 1];
    const previous = calls[index - 1];
    // The vector towards the following call; at a terminus, away from the
    // preceding one — the same orientation either way.
    const neighbor =
      next?.patternId === call.patternId
        ? { location: next.location, sign: 1 }
        : previous?.patternId === call.patternId
          ? { location: previous.location, sign: -1 }
          : undefined;
    if (!neighbor) continue;

    const offset = metersEastNorth(call.location, neighbor.location);
    const meters = Math.hypot(offset.east, offset.north);
    if (meters === 0) continue;

    const key = stationRouteKey(call.stopId, call.routeId);
    const vectors = travelVectorsByStationRoute.get(key) ?? [];
    if (!travelVectorsByStationRoute.has(key)) travelVectorsByStationRoute.set(key, vectors);

    const hopKey = `${key} ${call.directionId}`;
    const bestMeters = bestHopMeters.get(hopKey);
    if (bestMeters !== undefined && bestMeters <= meters) continue;
    bestHopMeters.set(hopKey, meters);

    const vector: TravelVector = {
      directionId: call.directionId,
      east: (neighbor.sign * offset.east) / meters,
      north: (neighbor.sign * offset.north) / meters,
    };
    const existing = vectors.findIndex((entry) => entry.directionId === call.directionId);
    if (existing === -1) vectors.push(vector);
    else vectors[existing] = vector;
  }

  return { stationLocationByStopId, travelVectorsByStationRoute };
}
