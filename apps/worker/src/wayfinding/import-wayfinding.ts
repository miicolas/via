import { db } from '@via/db';
import { boardingPositions, stationExits, transitStopAliases, transitStops } from '@via/db/schema';

import { datasetUpdatedAt, exportDataset, readStopAreaParents } from '../idfm/referential';
import { mapBoardingPositions, mapExits } from './map-wayfinding';

const INSERT_BATCH = 500;

/**
 * Imports the station exits and the carriage advice that goes with them.
 *
 * Must run after a GTFS import: exits attach to `transit_stops`, and every
 * boarding position is validated against `transit_stop_aliases`, which is where
 * quay ids come from. On an empty network it throws rather than committing a
 * snapshot that silently matches nothing.
 */
export async function refreshWayfindingSnapshot() {
  const [
    accesses,
    accessRelations,
    stopAreas,
    trainPositions,
    exitsUpdatedAt,
    positionsUpdatedAt,
  ] = await Promise.all([
    exportDataset('accesses'),
    exportDataset('accessRelations'),
    exportDataset('stopAreas'),
    exportDataset('trainPositions'),
    datasetUpdatedAt('accesses'),
    datasetUpdatedAt('trainPositions'),
  ]);

  const [stops, aliases] = await Promise.all([
    db.select({ id: transitStops.id }).from(transitStops),
    db.select({ sourceId: transitStopAliases.sourceId }).from(transitStopAliases),
  ]);

  const exits = mapExits({
    accesses,
    accessRelations,
    stopAreaParents: readStopAreaParents(stopAreas),
    knownStopIDs: new Set(stops.map((stop) => stop.id)),
  });
  if (exits.size === 0) throw new Error('No station exit matches the transit network');

  const positions = mapBoardingPositions({
    trainPositions,
    exitIDs: new Set(exits.keys()),
    knownQuayIDs: new Set(aliases.map((alias) => alias.sourceId)),
  });

  const importedAt = new Date();
  const exitRows = [...exits.values()];

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
