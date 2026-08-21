import { db } from '@via/db';
import {
  stationFacts,
  transitStops,
  type StationFactCondition,
} from '@via/db/schema';
import { eq, inArray } from 'drizzle-orm';

const ACCESSIBILITY_EXPORT =
  'https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/accessibilite-en-gare/exports/json';
const ACCESSIBILITY_CATALOG =
  'https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/accessibilite-en-gare';
const STOP_AREAS_EXPORT =
  'https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/zones-d-arrets/exports/json';

type AccessibilityRow = {
  stop_point_id?: unknown;
  accessibility_level_id?: unknown;
  commentaire?: unknown;
};

type StopAreaRow = { zdaid?: unknown; zdcid?: unknown };

type CatalogResponse = {
  metas?: { default?: { modified?: unknown; data_processed?: unknown } };
};

const CONDITION_BY_LEVEL = new Map<number, StationFactCondition>([
  [3, 'reservationRequired'],
  [4, 'staffAssistance'],
  [6, 'autonomous'],
]);

async function fetchJson(url: string) {
  const response = await fetch(url, { signal: AbortSignal.timeout(30_000) });
  if (!response.ok) throw new Error(`Accessibility source returned HTTP ${response.status}`);
  return response.json();
}

function asString(value: unknown) {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

function asInteger(value: unknown) {
  const number = typeof value === 'number' ? value : Number(value);
  return Number.isInteger(number) ? number : undefined;
}

function sourceStopAreaId(value: string) {
  const match = /^stop_point:IDFM:monomodalStopPlace:(.+)$/.exec(value);
  return match?.[1];
}

/** Imports the last complete IDFM accessibility declaration and its source timestamp. */
export async function refreshAccessibilitySnapshot() {
  const [accessibilityPayload, stopAreasPayload, catalogPayload] = await Promise.all([
    fetchJson(ACCESSIBILITY_EXPORT),
    fetchJson(STOP_AREAS_EXPORT),
    fetchJson(ACCESSIBILITY_CATALOG) as Promise<CatalogResponse>,
  ]);

  if (!Array.isArray(accessibilityPayload) || !Array.isArray(stopAreasPayload)) {
    throw new Error('Accessibility source payload is not an array');
  }

  const stopAreaByZdaid = new Map<string, string>();
  for (const row of stopAreasPayload as StopAreaRow[]) {
    const zdaid = asString(row.zdaid);
    const zdcid = asString(row.zdcid);
    if (zdaid && zdcid) stopAreaByZdaid.set(zdaid, zdcid);
  }

  const sourceRows = (accessibilityPayload as AccessibilityRow[]).flatMap((row) => {
    const sourceStopPointId = asString(row.stop_point_id);
    const levelId = asInteger(row.accessibility_level_id);
    const condition = levelId === undefined ? undefined : CONDITION_BY_LEVEL.get(levelId);
    const sourceAreaId = sourceStopPointId ? sourceStopAreaId(sourceStopPointId) : undefined;
    const canonicalAreaId = sourceAreaId ? stopAreaByZdaid.get(sourceAreaId) : undefined;
    if (!sourceStopPointId || !canonicalAreaId || !condition) return [];
    return [{
      stopId: `IDFM:${canonicalAreaId}`,
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

  const sourceUpdatedAt = asString(catalogPayload.metas?.default?.data_processed)
    ?? asString(catalogPayload.metas?.default?.modified);
  const importedAt = new Date();
  const sourceUpdatedAtDate = sourceUpdatedAt ? new Date(sourceUpdatedAt) : null;

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

  return { imported: rows.length, sourceUpdatedAt, importedAt: importedAt.toISOString() };
}
