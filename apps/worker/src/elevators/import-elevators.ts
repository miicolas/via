import { db } from '@via/db';
import { stationElevators, transitStops } from '@via/db/schema';
import { inArray } from 'drizzle-orm';

import { parseElevatorRows } from './parse-elevators';

const DEFAULT_DATASET_URL =
  'https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/etat-des-ascenseurs/exports/json';
const SOURCE = 'idfm:etat-des-ascenseurs';
const INSERT_BATCH = 500;

export type ElevatorImportResult = {
  imported: number;
  stations: number;
  sourceUpdatedAt?: string;
  importedAt: string;
};

/** Downloads and atomically replaces the current PRIM elevator snapshot. */
export async function refreshElevatorSnapshot(): Promise<ElevatorImportResult> {
  const payload = await fetchElevatorDataset();
  const sourceRows = parseElevatorRows(payload);
  if (sourceRows.length === 0) {
    throw new Error('Elevator source has no usable rows; previous snapshot was preserved');
  }

  const sourceStopIDs = [...new Set(sourceRows.map((row) => row.stopId))];
  const existingStops = await db
    .select({ id: transitStops.id })
    .from(transitStops)
    .where(inArray(transitStops.id, sourceStopIDs));
  const existing = new Set(existingStops.map((row) => row.id));
  const rows = sourceRows.filter((row) => existing.has(row.stopId));
  if (rows.length === 0) {
    throw new Error('Elevator source does not match the transit network');
  }

  const importedAt = new Date();
  await db.transaction(async (tx) => {
    await tx.delete(stationElevators);
    for (let start = 0; start < rows.length; start += INSERT_BATCH) {
      await tx.insert(stationElevators).values(
        rows.slice(start, start + INSERT_BATCH).map((row) => ({
          ...row,
          source: SOURCE,
          importedAt,
        }))
      );
    }
  });

  const sourceUpdatedAt = rows.reduce<Date | null>((latest, row) => {
    if (!row.stateUpdatedAt) return latest;
    return !latest || row.stateUpdatedAt > latest ? row.stateUpdatedAt : latest;
  }, null);

  return {
    imported: rows.length,
    stations: new Set(rows.map((row) => row.stopId)).size,
    sourceUpdatedAt: sourceUpdatedAt?.toISOString(),
    importedAt: importedAt.toISOString(),
  };
}

async function fetchElevatorDataset() {
  const token = process.env.PRIM_STATIC_DATA_TOKEN?.trim();
  if (!token) {
    throw new Error(
      'PRIM_STATIC_DATA_TOKEN is required (PRIM > Mes jetons > Données statiques)'
    );
  }

  const url = process.env.PRIM_ELEVATORS_DATASET_URL?.trim() || DEFAULT_DATASET_URL;
  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
      Authorization: `apikey ${token}`,
    },
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) throw new Error(`Elevator dataset returned HTTP ${response.status}`);

  return response.json();
}
