import { asString } from '../idfm/referential';

const MAX_MATCH_DISTANCE_METERS = 350;

type SourceCoordinate = {
  lon?: unknown;
  lat?: unknown;
};

type SourceRow = {
  ligne?: unknown;
  station?: unknown;
  accessible_au_public?: unknown;
  tarif_gratuit_payant?: unknown;
  acces_passe_navigo_ou_ticket_t?: unknown;
  en_zone_controlee?: unknown;
  hors_zone_controlee_station?: unknown;
  hors_zone_controlee_voie_publique?: unknown;
  accessibilite_pmr?: unknown;
  localisation?: unknown;
  coord_geo?: SourceCoordinate | null;
};

export type ToiletSourceRow = {
  stationName: string;
  lineShortName: string;
  latitude: number;
  longitude: number;
  price: 'free' | 'paid' | 'unknown';
  wheelchairAccessible: boolean | undefined;
  controlledArea: boolean | undefined;
  location: string | undefined;
  sourceRef: string;
};

export type ToiletStationCandidate = {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  routeShortNames: string[];
};

export type ToiletStationFact = {
  stopId: string;
  detail: string;
  sourceRef: string;
};

export type ToiletMapping = {
  facts: ToiletStationFact[];
  unmatched: ToiletSourceRow[];
};

/** Keeps only public, positioned facilities and translates the RATP vocabulary. */
export function parseToiletRows(payload: unknown): ToiletSourceRow[] {
  if (!Array.isArray(payload)) throw new Error('Toilet source payload is not an array');

  return (payload as SourceRow[]).flatMap((row) => {
    const stationName = asString(row.station)?.trim();
    const lineShortName = asString(row.ligne)?.trim();
    const latitude = asNumber(row.coord_geo?.lat);
    const longitude = asNumber(row.coord_geo?.lon);
    if (
      !stationName
      || !lineShortName
      || latitude === undefined
      || longitude === undefined
      || yesNo(row.accessible_au_public) !== true
    ) {
      return [];
    }

    const sourceRef = [stationName, lineShortName, latitude.toFixed(7), longitude.toFixed(7)]
      .join(':');
    const priceValue = normalized(asString(row.tarif_gratuit_payant));
    const outsideControlledArea = yesNo(row.hors_zone_controlee_station) === true
      || yesNo(row.hors_zone_controlee_voie_publique) === true;
    const insideControlledArea = yesNo(row.en_zone_controlee) === true
      || yesNo(row.acces_passe_navigo_ou_ticket_t) === true;

    return [{
      stationName,
      lineShortName,
      latitude,
      longitude,
      price: priceValue === 'gratuit' ? 'free' : priceValue === 'payant' ? 'paid' : 'unknown',
      wheelchairAccessible: yesNo(row.accessibilite_pmr),
      controlledArea: insideControlledArea ? true : outsideControlledArea ? false : undefined,
      location: asString(row.localisation)?.trim(),
      sourceRef,
    }];
  });
}

/**
 * Matches each facility by station name and line, with distance as the final guard.
 * A facility can sit in a connecting concourse whose published line is not served
 * by Via's nearest station node, so a nearby exact name is accepted before the
 * line-only fallback. Coordinates are approximate according to the publisher.
 */
export function mapToiletFacts(
  rows: ToiletSourceRow[],
  candidates: ToiletStationCandidate[]
): ToiletMapping {
  const rowsByStopID = new Map<string, ToiletSourceRow[]>();
  const candidateByID = new Map(candidates.map((candidate) => [candidate.id, candidate]));
  const unmatched: ToiletSourceRow[] = [];

  for (const row of rows) {
    const lineCandidates = candidates.filter((candidate) =>
      candidate.routeShortNames.includes(row.lineShortName)
    );
    const exactNameCandidates = candidates.filter((candidate) =>
      normalizeName(candidate.name) === normalizeName(row.stationName)
    );
    const exactNameAndLineCandidates = exactNameCandidates.filter((candidate) =>
      candidate.routeShortNames.includes(row.lineShortName)
    );
    const match = nearestWithinRange(row, exactNameAndLineCandidates)
      ?? nearestWithinRange(row, exactNameCandidates)
      ?? nearestWithinRange(row, lineCandidates);

    if (!match) {
      unmatched.push(row);
      continue;
    }

    const stationRows = rowsByStopID.get(match.id) ?? [];
    stationRows.push(row);
    rowsByStopID.set(match.id, stationRows);
  }

  const facts = [...rowsByStopID.entries()]
    .map(([stopId, stationRows]) => ({
      stopId,
      detail: toiletDetail(stationRows),
      sourceRef: stationRows.map((row) => row.sourceRef).sort().join('|'),
      stationName: candidateByID.get(stopId)?.name ?? stopId,
    }))
    .sort((lhs, rhs) => lhs.stationName.localeCompare(rhs.stationName, 'fr'))
    .map(({ stationName: _, ...fact }) => fact);

  return { facts, unmatched };
}

function nearestWithinRange(row: ToiletSourceRow, candidates: ToiletStationCandidate[]) {
  const candidate = nearestCandidate(row, candidates);
  return candidate && distanceMeters(row, candidate) <= MAX_MATCH_DISTANCE_METERS
    ? candidate
    : undefined;
}

function nearestCandidate(row: ToiletSourceRow, candidates: ToiletStationCandidate[]) {
  return candidates.reduce<ToiletStationCandidate | undefined>((nearest, candidate) => {
    if (!nearest) return candidate;
    return distanceMeters(row, candidate) < distanceMeters(row, nearest) ? candidate : nearest;
  }, undefined);
}

function toiletDetail(rows: ToiletSourceRow[]) {
  const summary = [priceLabel(rows), wheelchairLabel(rows), controlledAreaLabel(rows)]
    .filter((value): value is string => value !== undefined)
    .join(' · ');
  const locations = [...new Set(rows.map((row) => row.location).filter(
    (value): value is string => value !== undefined
  ))];
  const locationText = locations.length > 1
    ? locations.map((location) => `• ${location}`).join('\n')
    : locations[0];

  return [summary, locationText].filter(Boolean).join('\n');
}

function priceLabel(rows: ToiletSourceRow[]) {
  const prices = new Set(rows.map((row) => row.price).filter((price) => price !== 'unknown'));
  if (prices.size === 0) return undefined;
  if (prices.size > 1) return 'Accès gratuit ou payant';
  return prices.has('free') ? 'Accès gratuit' : 'Accès payant';
}

function wheelchairLabel(rows: ToiletSourceRow[]) {
  const values = new Set(rows.map((row) => row.wheelchairAccessible).filter(
    (value): value is boolean => value !== undefined
  ));
  if (values.size === 0) return undefined;
  if (values.size > 1) return 'Accessibilité PMR selon l’emplacement';
  return values.has(true) ? 'Accessible PMR' : 'Non accessible PMR';
}

function controlledAreaLabel(rows: ToiletSourceRow[]) {
  const values = new Set(rows.map((row) => row.controlledArea).filter(
    (value): value is boolean => value !== undefined
  ));
  if (values.size === 0 || values.size > 1) return undefined;
  return values.has(true) ? 'En zone contrôlée' : 'Hors zone contrôlée';
}

function normalizeName(value: string) {
  return normalized(value).replace(/[^a-z0-9]+/g, ' ').trim();
}

function normalized(value: string | undefined) {
  return value?.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLocaleLowerCase('fr') ?? '';
}

function yesNo(value: unknown): boolean | undefined {
  const parsed = normalized(asString(value)?.trim());
  if (parsed === 'oui') return true;
  if (parsed === 'non') return false;
  return undefined;
}

function asNumber(value: unknown) {
  if (value === null || value === undefined || value === '') return undefined;
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function distanceMeters(
  lhs: Pick<ToiletSourceRow, 'latitude' | 'longitude'>,
  rhs: Pick<ToiletStationCandidate, 'latitude' | 'longitude'>
) {
  const radians = Math.PI / 180;
  const latitudeDelta = (rhs.latitude - lhs.latitude) * radians;
  const longitudeDelta = (rhs.longitude - lhs.longitude) * radians;
  const latitudeA = lhs.latitude * radians;
  const latitudeB = rhs.latitude * radians;
  const haversine = Math.sin(latitudeDelta / 2) ** 2
    + Math.cos(latitudeA) * Math.cos(latitudeB) * Math.sin(longitudeDelta / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.sqrt(haversine));
}
