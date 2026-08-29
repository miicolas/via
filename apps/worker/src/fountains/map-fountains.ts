import { asString, viaId } from '../idfm/referential';

type FountainSourcePayload = {
  id?: unknown;
  zdcid?: unknown;
  indisponible?: unknown;
  accessible_pmr?: unknown;
  remplissage_contenant_possible?: unknown;
  condition_acces?: unknown;
  adresse?: unknown;
};

export type FountainSourceRow = {
  id: string;
  stopId: string;
  isAvailable: boolean;
  unavailableSince: string | undefined;
  isWheelchairAccessible: boolean | undefined;
  canFillContainer: boolean | undefined;
  accessCondition: string | undefined;
  address: string | undefined;
};

export type FountainStationFact = {
  stopId: string;
  condition: 'available' | 'unavailable';
  detail: string;
  sourceRef: string;
};

/** Translates the open-data sentinel values and canonical ZdC ids into Via rows. */
export function parseFountainRows(payload: unknown): FountainSourceRow[] {
  if (!Array.isArray(payload)) throw new Error('Fountain source payload is not an array');

  const rows = new Map<string, FountainSourceRow>();
  for (const source of payload as FountainSourcePayload[]) {
    const id = sourceValue(source.id);
    const zdcid = sourceValue(source.zdcid);
    if (!id || !zdcid) continue;
    if (rows.has(id)) throw new Error(`Fountain source contains duplicate id ${id}`);

    const unavailableSince = sourceValue(source.indisponible);

    rows.set(id, {
      id,
      stopId: viaId(zdcid),
      isAvailable: unavailableSince === undefined,
      unavailableSince,
      isWheelchairAccessible: sourceBoolean(source.accessible_pmr),
      canFillContainer: sourceBoolean(source.remplissage_contenant_possible),
      accessCondition: sourceValue(source.condition_acces),
      address: sourceValue(source.adresse),
    });
  }

  return [...rows.values()];
}

/** One station fact summarizes every fountain published for the same connection area. */
export function mapFountainFacts(rows: FountainSourceRow[]): FountainStationFact[] {
  return [...Map.groupBy(rows, (row) => row.stopId).entries()]
    .map(([stopId, stationRows]) => {
      const availableRows = stationRows.filter((row) => row.isAvailable);
      return {
        stopId,
        condition: availableRows.length > 0 ? 'available' as const : 'unavailable' as const,
        detail: fountainDetail(stationRows, availableRows),
        sourceRef: stationRows.map((row) => row.id).sort().join('|'),
      };
    })
    .sort((lhs, rhs) => lhs.stopId.localeCompare(rhs.stopId));
}

function fountainDetail(rows: FountainSourceRow[], availableRows: FountainSourceRow[]) {
  const describedRows = availableRows.length > 0 ? availableRows : rows;
  const lines: string[] = [];

  if (rows.length > 1) {
    if (availableRows.length === rows.length) {
      lines.push(`${rows.length} fontaines recensées.`);
    } else if (availableRows.length > 0) {
      lines.push(`${availableRows.length} fontaine disponible sur ${rows.length}.`);
    } else {
      lines.push(`${rows.length} fontaines recensées, toutes signalées indisponibles.`);
    }
  }

  const unavailableDates = unique(describedRows.map((row) => row.unavailableSince))
    .map(formatSourceDate);
  if (unavailableDates.length === 1) {
    lines.push(`Début de l’indisponibilité : ${unavailableDates[0]}.`);
  } else if (unavailableDates.length > 1) {
    lines.push(`Débuts d’indisponibilité : ${unavailableDates.join(' · ')}.`);
  }

  const qualities = [
    booleanSummary(
      describedRows.map((row) => row.isWheelchairAccessible),
      'Accessible PMR',
      'Non accessible PMR',
      'Accessibilité PMR selon la fontaine'
    ),
    booleanSummary(
      describedRows.map((row) => row.canFillContainer),
      'Remplissage de gourde possible',
      'Remplissage de gourde impossible',
      'Remplissage de gourde selon la fontaine'
    ),
  ].filter((value): value is string => value !== undefined);
  if (qualities.length > 0) lines.push(qualities.join(' · '));

  const conditions = unique(describedRows.map((row) => row.accessCondition));
  if (conditions.length === 1) lines.push(conditions[0]!);
  if (conditions.length > 1) lines.push(...conditions.map((condition) => `• ${condition}`));

  const addresses = unique(describedRows.map((row) => row.address));
  if (addresses.length === 1) {
    lines.push(`Adresse : ${addresses[0]}`);
  } else if (addresses.length > 1) {
    lines.push(...addresses.map((address) => `• ${address}`));
  } else {
    // IDFM currently publishes the station coordinate, not the fountain's
    // exact position. Saying so prevents a station badge from promising that
    // the fountain sits inside the paid area or beside a particular entrance.
    lines.push('Emplacement précis non renseigné par Île-de-France Mobilités.');
  }

  return lines.join('\n');
}

function booleanSummary(
  values: Array<boolean | undefined>,
  everyTrue: string,
  everyFalse: string,
  mixed: string
) {
  const known = values.filter((value): value is boolean => value !== undefined);
  if (known.length === 0) return undefined;
  if (values.every((value) => value === true)) return everyTrue;
  if (values.every((value) => value === false)) return everyFalse;
  return mixed;
}

function unique(values: Array<string | undefined>) {
  return [...new Set(values.filter((value): value is string => value !== undefined))];
}

function formatSourceDate(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})(?:T.*)?$/.exec(value);
  if (!match) return value;

  const date = new Date(`${match[1]}-${match[2]}-${match[3]}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat('fr-FR', { dateStyle: 'long', timeZone: 'UTC' }).format(date);
}

function sourceValue(value: unknown) {
  const parsed = asString(value)?.trim();
  return parsed && parsed.toUpperCase() !== 'NULL' ? parsed : undefined;
}

function sourceBoolean(value: unknown): boolean | undefined {
  if (typeof value === 'boolean') return value;
  const parsed = sourceValue(value)?.toLocaleLowerCase('fr');
  if (parsed === 'true' || parsed === 'oui' || parsed === '1') return true;
  if (parsed === 'false' || parsed === 'non' || parsed === '0') return false;
  return undefined;
}
