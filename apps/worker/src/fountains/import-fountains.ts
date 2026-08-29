import { db } from '@via/db';
import { stationFacts, transitStops } from '@via/db/schema';
import { eq, inArray } from 'drizzle-orm';

import { datasetUpdatedAt, exportDataset } from '../idfm/referential';
import { bumpTransitNetworkCacheVersion } from '../network-cache-version';
import { replaceSnapshot } from '../snapshot-importer';
import { mapFountainFacts, parseFountainRows } from './map-fountains';

const SOURCE = 'idfm:fontaines-arrets-de-transport-en-commun-didf';

export type FountainImportResult = {
  imported: number;
  skipped: boolean;
  sourceUpdatedAt?: string;
  importedAt: string;
};

/** Imports the complete drinking-water snapshot and preserves the last valid one on drift. */
export async function refreshFountainSnapshot(): Promise<FountainImportResult> {
  const [payload, sourceUpdatedAtDate] = await Promise.all([
    exportDataset('fountains'),
    datasetUpdatedAt('fountains'),
  ]);
  const sourceUpdatedAt = sourceUpdatedAtDate?.toISOString();

  const previous = await db
    .select({ sourceUpdatedAt: stationFacts.sourceUpdatedAt })
    .from(stationFacts)
    .where(eq(stationFacts.kind, 'fountains'))
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

  const sourceRows = parseFountainRows(payload);
  if (sourceRows.length === 0) throw new Error('Fountain source has no usable facilities');

  const facts = mapFountainFacts(sourceRows);
  const stopIDs = facts.map((fact) => fact.stopId);
  const existingStops = await db
    .select({ id: transitStops.id })
    .from(transitStops)
    .where(inArray(transitStops.id, stopIDs));
  const existing = new Set(existingStops.map((row) => row.id));
  const unmatched = facts.filter((fact) => !existing.has(fact.stopId));
  if (unmatched.length > 0) {
    throw new Error(
      `Fountain source has unmapped connection areas: ${unmatched.map((row) => row.stopId).join(', ')}`
    );
  }

  const { rows, importedAt } = await replaceSnapshot({
    prepare: async () => facts,
    emptyMessage: 'Fountain source does not match the transit network',
    onCommit: bumpTransitNetworkCacheVersion,
    write: async (tx, rows, importedAt) => {
      await tx.delete(stationFacts).where(eq(stationFacts.kind, 'fountains'));
      await tx.insert(stationFacts).values(rows.map((fact) => ({
        ...fact,
        kind: 'fountains' as const,
        source: SOURCE,
        sourceUpdatedAt: sourceUpdatedAtDate,
        importedAt,
      })));
    },
  });

  return {
    imported: rows.length,
    skipped: false,
    sourceUpdatedAt,
    importedAt: importedAt.toISOString(),
  };
}
