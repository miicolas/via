import { db } from '@via/db';
import {
  stationFacts,
  transitStops,
  type AccessibilityStationFactCondition,
} from '@via/db/schema';
import { eq, inArray } from 'drizzle-orm';

import {
  asInteger,
  asString,
  datasetUpdatedAt,
  exportDataset,
  readStopAreaParents,
  viaId,
} from '../idfm/referential';

type AccessibilityRow = {
  stop_point_id?: unknown;
  accessibility_level_id?: unknown;
  commentaire?: unknown;
};

const CONDITION_BY_LEVEL = new Map<number, AccessibilityStationFactCondition>([
  [3, 'reservationRequired'],
  [4, 'staffAssistance'],
  [6, 'autonomous'],
]);

function sourceStopAreaId(value: string) {
  const match = /^stop_point:IDFM:monomodalStopPlace:(.+)$/.exec(value);
  return match?.[1];
}

/** Imports the last complete IDFM accessibility declaration and its source timestamp. */
export async function refreshAccessibilitySnapshot() {
  const [accessibilityPayload, stopAreasPayload, sourceUpdatedAtDate] = await Promise.all([
    exportDataset('accessibility'),
    exportDataset('stopAreas'),
    datasetUpdatedAt('accessibility'),
  ]);

  const stopAreaByZdaid = readStopAreaParents(stopAreasPayload);

  const sourceRows = (accessibilityPayload as AccessibilityRow[]).flatMap((row) => {
    const sourceStopPointId = asString(row.stop_point_id);
    const levelId = asInteger(row.accessibility_level_id);
    const condition = levelId === undefined ? undefined : CONDITION_BY_LEVEL.get(levelId);
    const sourceAreaId = sourceStopPointId ? sourceStopAreaId(sourceStopPointId) : undefined;
    const canonicalAreaId = sourceAreaId ? stopAreaByZdaid.get(sourceAreaId) : undefined;
    if (!sourceStopPointId || !canonicalAreaId || !condition) return [];
    return [{
      stopId: viaId(canonicalAreaId),
      kind: 'accessibility' as const,
      condition,
      detail: asString(row.commentaire) ?? null,
      source: 'idfm:acces-gare',
      sourceRef: sourceStopPointId,
    }];
  });

  if (sourceRows.length === 0) throw new Error('Accessibility source has no mappable rows');

  const stopIDs = [...new Set(sourceRows.map((row) => row.stopId))];
  const existingStops = await db
    .select({ id: transitStops.id })
    .from(transitStops)
    .where(inArray(transitStops.id, stopIDs));
  const existing = new Set(existingStops.map((row) => row.id));
  const rowsByStopId = new Map(
    sourceRows
      .filter((row) => existing.has(row.stopId))
      .map((row) => [row.stopId, row] as const)
  );
  const rows = [...rowsByStopId.values()];
  if (rows.length === 0) throw new Error('Accessibility source does not match the transit network');

  const importedAt = new Date();

  await db.transaction(async (tx) => {
    await tx.delete(stationFacts).where(eq(stationFacts.kind, 'accessibility'));
    for (let start = 0; start < rows.length; start += 500) {
      await tx.insert(stationFacts).values(
        rows.slice(start, start + 500).map((row) => ({
          ...row,
          sourceUpdatedAt: sourceUpdatedAtDate,
          importedAt,
        }))
      );
    }
  });

  return {
    imported: rows.length,
    sourceUpdatedAt: sourceUpdatedAtDate?.toISOString(),
    importedAt: importedAt.toISOString(),
  };
}
