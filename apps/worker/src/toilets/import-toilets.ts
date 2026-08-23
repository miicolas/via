import { db } from '@via/db';
import {
  stationFacts,
  transitRoutes,
  transitStopRoutes,
  transitStops,
} from '@via/db/schema';
import { drawnRouteCondition } from '@via/db/network-scope';
import { and, eq, sql } from 'drizzle-orm';

import { datasetUpdatedAt, exportDataset } from '../idfm/referential';
import { mapToiletFacts, parseToiletRows, type ToiletStationCandidate } from './map-toilets';

const SOURCE = 'idfm:sanitaires-reseau-ratp';

export type ToiletImportResult = {
  imported: number;
  skipped: boolean;
  sourceUpdatedAt?: string;
  importedAt: string;
};

/** Imports the complete public-toilet snapshot, preserving the last valid one on source drift. */
export async function refreshToiletSnapshot(): Promise<ToiletImportResult> {
  const [payload, sourceUpdatedAtDate] = await Promise.all([
    exportDataset('toilets'),
    datasetUpdatedAt('toilets'),
  ]);
  const sourceUpdatedAt = sourceUpdatedAtDate?.toISOString();

  const previous = await db
    .select({ sourceUpdatedAt: stationFacts.sourceUpdatedAt })
    .from(stationFacts)
    .where(eq(stationFacts.kind, 'toilets'))
    .limit(1);
  if (
    sourceUpdatedAtDate
    && previous[0]?.sourceUpdatedAt?.getTime() === sourceUpdatedAtDate.getTime()
  ) {
    return {
      imported: 0,
      skipped: true,
      sourceUpdatedAt,
      importedAt: new Date().toISOString(),
    };
  }

  const sourceRows = parseToiletRows(payload);
  if (sourceRows.length === 0) throw new Error('Toilet source has no usable public facilities');

  const candidates = await stationCandidates();
  const mapping = mapToiletFacts(sourceRows, candidates);
  if (mapping.unmatched.length > 0) {
    const labels = mapping.unmatched
      .map((row) => `${row.stationName} (${row.lineShortName})`)
      .join(', ');
    throw new Error(`Toilet source has unmapped facilities: ${labels}`);
  }
  if (mapping.facts.length === 0) throw new Error('Toilet source does not match the transit network');

  const importedAt = new Date();
  await db.transaction(async (tx) => {
    await tx.delete(stationFacts).where(eq(stationFacts.kind, 'toilets'));
    await tx.insert(stationFacts).values(mapping.facts.map((fact) => ({
      stopId: fact.stopId,
      kind: 'toilets' as const,
      condition: 'available' as const,
      detail: fact.detail || null,
      source: SOURCE,
      sourceRef: fact.sourceRef,
      sourceUpdatedAt: sourceUpdatedAtDate,
      importedAt,
    })));
  });

  return {
    imported: mapping.facts.length,
    skipped: false,
    sourceUpdatedAt,
    importedAt: importedAt.toISOString(),
  };
}

async function stationCandidates(): Promise<ToiletStationCandidate[]> {
  const rows = await db
    .select({
      id: transitStops.id,
      name: transitStops.name,
      latitude: sql<number>`ST_Y(${transitStops.location})`,
      longitude: sql<number>`ST_X(${transitStops.location})`,
      routeShortNames: sql<string[]>`array_agg(
        DISTINCT ${transitRoutes.shortName} ORDER BY ${transitRoutes.shortName}
      )`,
    })
    .from(transitStops)
    .innerJoin(transitStopRoutes, eq(transitStopRoutes.stopId, transitStops.id))
    .innerJoin(transitRoutes, eq(transitStopRoutes.routeId, transitRoutes.id))
    .where(and(drawnRouteCondition()))
    .groupBy(transitStops.id, transitStops.name);

  return rows.map((row) => ({
    ...row,
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
  }));
}
