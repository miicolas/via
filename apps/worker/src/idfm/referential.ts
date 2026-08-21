/**
 * The Île-de-France stop referential, as published on Opendatasoft.
 *
 * Every dataset here is keyless and rate-limit-free, unlike the PRIM marketplace
 * endpoints the API calls at request time. Importers may pull them freely; they
 * spend none of the daily PRIM budget.
 *
 * The referential nests three levels, and Via's canonical station is the
 * outermost one:
 *
 *   Acc (access)  →  ArR (quay)  →  ZdA (stop area)  →  ZdC (connection area)
 *                                                        = `transit_stops.id`
 *
 * So an id coming out of any of these datasets has to be walked up before it
 * matches a Via station — see {@link readStopAreaParents}.
 */

const CATALOG = 'https://data.iledefrance-mobilites.fr/api/explore/v2.1/catalog/datasets';

export const REFERENTIAL_DATASETS = {
  accessibility: `${CATALOG}/accessibilite-en-gare`,
  accesses: `${CATALOG}/acces`,
  accessRelations: `${CATALOG}/relations-acces`,
  stopAreas: `${CATALOG}/zones-d-arrets`,
  trainPositions: `${CATALOG}/positionnement-dans-la-rame`,
} as const;

export type ReferentialDataset = keyof typeof REFERENTIAL_DATASETS;

type CatalogResponse = {
  metas?: { default?: { modified?: unknown; data_processed?: unknown } };
};

export async function fetchOpenDataJson(url: string) {
  const response = await fetch(url, { signal: AbortSignal.timeout(30_000) });
  if (!response.ok) throw new Error(`${url} returned HTTP ${response.status}`);
  return response.json();
}

/** Every row of a dataset, in one request — the referential is small enough. */
export async function exportDataset(dataset: ReferentialDataset) {
  const payload = await fetchOpenDataJson(`${REFERENTIAL_DATASETS[dataset]}/exports/json`);
  if (!Array.isArray(payload)) throw new Error(`Dataset ${dataset} did not export an array`);
  return payload as Record<string, unknown>[];
}

/**
 * When the publisher itself says the dataset last changed. Stored next to the
 * rows so a stale referential is visible without diffing it.
 */
export async function datasetUpdatedAt(dataset: ReferentialDataset) {
  const payload = (await fetchOpenDataJson(REFERENTIAL_DATASETS[dataset])) as CatalogResponse;
  const value = asString(payload.metas?.default?.data_processed)
    ?? asString(payload.metas?.default?.modified);
  return value ? new Date(value) : null;
}

export function asString(value: unknown) {
  if (typeof value === 'string') return value.length > 0 ? value : undefined;
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  return undefined;
}

export function asInteger(value: unknown) {
  const number = typeof value === 'number' ? value : Number(value);
  return Number.isInteger(number) ? number : undefined;
}

/** `{ zdaid → zdcid }`, the last hop from a referential id to a Via station. */
export function readStopAreaParents(rows: Record<string, unknown>[]) {
  const parents = new Map<string, string>();
  for (const row of rows) {
    const zdaid = asString(row.zdaid);
    const zdcid = asString(row.zdcid);
    if (zdaid && zdcid) parents.set(zdaid, zdcid);
  }
  return parents;
}

/** Referential ids are bare numbers; Via prefixes them, as GTFS does. */
export function viaId(referentialId: string) {
  return `IDFM:${referentialId}`;
}
