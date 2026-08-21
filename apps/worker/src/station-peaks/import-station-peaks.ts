import { db } from '@via/db';
import { stationHourProfiles, transitStops } from '@via/db/schema';
import { inArray } from 'drizzle-orm';

const DATASET_ID = 'validations-reseau-ferre-profils-horaires-par-jour-type-4eme-trimestre';
const DATASET_EXPORT =
  `https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/${DATASET_ID}/exports/json`;
const DATASET_CATALOG =
  `https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets/${DATASET_ID}`;
const SOURCE = 'idfm:profils-horaires-t4';
const INSERT_BATCH = 500;

export type StationPeakDayType = 'weekday' | 'saturday' | 'sunday';

const DAY_TYPES = ['weekday', 'saturday', 'sunday'] as const;
const DAY_TYPE_BY_CATEGORY: Record<string, StationPeakDayType | undefined> = {
  JOHV: 'weekday',
  SAHV: 'saturday',
  DIJFP: 'sunday',
};

type SourceRow = {
  id_zdc?: unknown;
  libelle_arret?: unknown;
  cat_jour?: unknown;
  trnc_horr_60?: unknown;
  pourcentage_validations?: unknown;
};

type CatalogResponse = {
  metas?: { default?: { modified?: unknown; data_processed?: unknown } };
};

export type ParsedStationPeak = {
  stopId: string;
  dayType: StationPeakDayType;
  hour: number;
  share: number;
};

export type StationPeakImportResult = {
  imported: number;
  skipped: boolean;
  sourceUpdatedAt?: string;
  importedAt: string;
};

/** Converts the source rows into the three day types used by the API. */
export function parseStationPeakRows(payload: unknown): ParsedStationPeak[] {
  if (!Array.isArray(payload)) throw new Error('Station peak source payload is not an array');

  const values = new Map<string, ParsedStationPeak>();
  for (const raw of payload as SourceRow[]) {
    const category = asString(raw.cat_jour);
    const dayType = category ? DAY_TYPE_BY_CATEGORY[category] : undefined;
    const sourceID = asString(raw.id_zdc);
    const hour = parseHour(raw.trnc_horr_60);
    const share = asNumber(raw.pourcentage_validations);
    if (!dayType || !sourceID || hour === undefined || share === undefined) continue;

    const row = {
      stopId: `IDFM:${sourceID}`,
      dayType,
      hour,
      share: Math.max(0, share),
    } satisfies ParsedStationPeak;
    values.set(`${row.stopId}\u0000${row.dayType}\u0000${row.hour}`, row);
  }

  return [...values.values()];
}

/** Completes missing source combinations and calculates the station-relative peak ratio. */
export function completeStationPeakRows(
  sourceRows: ParsedStationPeak[],
  existingStopIDs: Iterable<string>,
  sourceUpdatedAt: Date,
  importedAt: Date
) {
  const sourceByKey = new Map(
    sourceRows.map((row) => [`${row.stopId}\u0000${row.dayType}\u0000${row.hour}`, row.share])
  );
  const existing = new Set(existingStopIDs);
  const matchedStopIDs = [...new Set(sourceRows.map((row) => row.stopId))].filter((stopId) =>
    existing.has(stopId)
  );
  if (matchedStopIDs.length === 0) {
    throw new Error('Station peak source does not match the transit network');
  }

  return matchedStopIDs.flatMap((stopId) => {
    return DAY_TYPES.flatMap((dayType) => {
      const shares = Array.from({ length: 24 }, (_, hour) =>
        sourceByKey.get(`${stopId}\u0000${dayType}\u0000${hour}`) ?? 0
      );
      const peak = Math.max(...shares);
      return shares.map((share, hour) => ({
        stopId,
        dayType,
        hour,
        share,
        peakRatio: peak > 0 ? share / peak : 0,
        source: SOURCE,
        sourceUpdatedAt,
        importedAt,
      }));
    });
  });
}

/** Imports the latest T4 profiles, replacing the previous snapshot atomically. */
export async function refreshStationPeakSnapshot(): Promise<StationPeakImportResult> {
  const [sourcePayload, catalogPayload] = await Promise.all([
    fetchJson(DATASET_EXPORT),
    fetchJson(DATASET_CATALOG) as Promise<CatalogResponse>,
  ]);
  const sourceUpdatedAt = asString(
    catalogPayload.metas?.default?.data_processed ?? catalogPayload.metas?.default?.modified
  );
  if (!sourceUpdatedAt) throw new Error('Station peak source has no freshness timestamp');

  const sourceUpdatedAtDate = new Date(sourceUpdatedAt);
  if (Number.isNaN(sourceUpdatedAtDate.getTime())) {
    throw new Error(`Station peak source has an invalid freshness timestamp: ${sourceUpdatedAt}`);
  }

  const previous = await db
    .select({ sourceUpdatedAt: stationHourProfiles.sourceUpdatedAt })
    .from(stationHourProfiles)
    .limit(1);
  if (
    previous[0]?.sourceUpdatedAt &&
    previous[0].sourceUpdatedAt.getTime() === sourceUpdatedAtDate.getTime()
  ) {
    return {
      imported: 0,
      skipped: true,
      sourceUpdatedAt,
      importedAt: new Date().toISOString(),
    };
  }

  const parsedRows = parseStationPeakRows(sourcePayload);
  if (parsedRows.length === 0) throw new Error('Station peak source has no usable rows');

  const sourceStopIDs = [...new Set(parsedRows.map((row) => row.stopId))];
  const existingStops = await db
    .select({ id: transitStops.id })
    .from(transitStops)
    .where(inArray(transitStops.id, sourceStopIDs));
  const importedAt = new Date();
  const rows = completeStationPeakRows(
    parsedRows,
    existingStops.map((row) => row.id),
    sourceUpdatedAtDate,
    importedAt
  );

  await db.transaction(async (tx) => {
    await tx.delete(stationHourProfiles);
    for (let start = 0; start < rows.length; start += INSERT_BATCH) {
      await tx.insert(stationHourProfiles).values(rows.slice(start, start + INSERT_BATCH));
    }
  });

  return {
    imported: rows.length,
    skipped: false,
    sourceUpdatedAt,
    importedAt: importedAt.toISOString(),
  };
}

async function fetchJson(url: string) {
  const response = await fetch(url, { signal: AbortSignal.timeout(30_000) });
  if (!response.ok) throw new Error(`Station peak source returned HTTP ${response.status}`);
  return response.json();
}

function asString(value: unknown) {
  if (typeof value === 'string' && value.length > 0) return value;
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  return undefined;
}

function asNumber(value: unknown) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : undefined;
  if (typeof value !== 'string' || value.trim().length === 0) return undefined;
  const parsed = Number(value.replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : undefined;
}

function parseHour(value: unknown): number | undefined {
  const match = /^(\d{1,2})H-\d{1,2}H$/.exec(String(value ?? ''));
  if (!match) return undefined;
  const hour = Number(match[1]);
  return Number.isInteger(hour) && hour >= 0 && hour < 24 ? hour : undefined;
}
