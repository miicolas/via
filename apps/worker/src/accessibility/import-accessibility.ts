import { db } from '@via/db';
import {
  importMeta,
  stationAccessibility,
  transitStops,
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
  accessibility_level_name?: unknown;
  commentaire?: unknown;
};

type StopAreaRow = { zdaid?: unknown; zdcid?: unknown };

type CatalogResponse = {
  metas?: { default?: { modified?: unknown; data_processed?: unknown } };
};

const IMPORTED_AT_KEY = 'accessibility:imported-at';
const SOURCE_UPDATED_AT_KEY = 'accessibility:source-updated-at';

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
    const levelName = asString(row.accessibility_level_name);
    const sourceAreaId = sourceStopPointId ? sourceStopAreaId(sourceStopPointId) : undefined;
    const canonicalAreaId = sourceAreaId ? stopAreaByZdaid.get(sourceAreaId) : undefined;
    if (!sourceStopPointId || !canonicalAreaId || levelId === undefined || !levelName) return [];
    return [{
      sourceStopPointId,
      stopId: `IDFM:${canonicalAreaId}`,
      levelId,
      levelName,
      comment: asString(row.commentaire) ?? null,
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
  const importedAt = new Date().toISOString();

  await db.transaction(async (tx) => {
    await tx.delete(stationAccessibility);
    for (let start = 0; start < rows.length; start += 500) {
      await tx.insert(stationAccessibility).values(
        rows.slice(start, start + 500).map((row) => ({
          ...row,
          importedAt: new Date(importedAt),
        }))
      );
    }
    const metadata = [
      { key: IMPORTED_AT_KEY, value: importedAt },
      ...(sourceUpdatedAt ? [{ key: SOURCE_UPDATED_AT_KEY, value: sourceUpdatedAt }] : []),
    ];
    if (!sourceUpdatedAt) {
      await tx.delete(importMeta).where(eq(importMeta.key, SOURCE_UPDATED_AT_KEY));
    }
    for (const entry of metadata) {
      await tx
        .insert(importMeta)
        .values(entry)
        .onConflictDoUpdate({
          target: importMeta.key,
          set: { value: entry.value, updatedAt: new Date(importedAt) },
        });
    }
  });

  return { imported: rows.length, sourceUpdatedAt, importedAt };
}
