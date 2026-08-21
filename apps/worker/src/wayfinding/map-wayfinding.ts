import type {
  BoardingPositionEquipment,
  BoardingPositionZone,
  LonLat,
} from '@via/db/schema';

import { asInteger, asString, viaId } from '../idfm/referential';

/**
 * Turns the two IDFM wayfinding datasets into rows, with no I/O.
 *
 * The source vocabulary stops here: nothing downstream should ever see `Avant`,
 * `Ascenseur` or a bare referential id — same contract as the accessibility
 * importer, which translates IDFM levels into Via conditions at write time.
 */

export type MappedExit = {
  id: string;
  stopId: string;
  name: string;
  number: number | null;
  detail: string | null;
  location: LonLat;
  source: string;
  sourceRef: string;
};

export type MappedBoardingPosition = {
  fromQuayId: string;
  targetId: string;
  targetKind: 'exit' | 'transfer';
  routeId: string;
  car: number;
  carCount: number;
  zone: BoardingPositionZone;
  equipment: BoardingPositionEquipment | null;
  source: string;
};

export const EXIT_SOURCE = 'idfm:acces';
export const BOARDING_POSITION_SOURCE = 'idfm:positionnement-dans-la-rame';

const ZONE_BY_LABEL = new Map<string, BoardingPositionZone>([
  ['Avant', 'front'],
  ['Milieu', 'middle'],
  ['Arrière', 'rear'],
]);

const EQUIPMENT_BY_LABEL = new Map<string, BoardingPositionEquipment>([
  ['Escalator', 'escalator'],
  ['Ascenseur', 'lift'],
  ['Escalier', 'stairs'],
]);

/**
 * `position_average` is the source's own wording and one row carries a stray
 * `'7'`, so it is only ever a hint: the car number and the train length always
 * agree with each other, and thirds of a train are what riders are told to aim
 * for anyway.
 */
export function zoneOf(label: string | undefined, car: number, carCount: number) {
  const declared = label ? ZONE_BY_LABEL.get(label) : undefined;
  if (declared) return declared;
  if (car * 3 <= carCount) return 'front';
  if (car * 3 > carCount * 2) return 'rear';
  return 'middle';
}

type AccessRow = {
  accid?: unknown;
  accname?: unknown;
  accshortname?: unknown;
  accdescription?: unknown;
  accisexit?: unknown;
  accgeopoint?: unknown;
};

type AccessRelationRow = { accid?: unknown; zdaid?: unknown };

type TrainPositionRow = {
  from_type?: unknown;
  from_id?: unknown;
  line_id?: unknown;
  to_type?: unknown;
  to_id?: unknown;
  position?: unknown;
  position_max?: unknown;
  position_average?: unknown;
  equipment_type?: unknown;
};

function coordinateOf(value: unknown) {
  const point = value as { lon?: unknown; lat?: unknown } | undefined;
  const lon = typeof point?.lon === 'number' ? point.lon : Number.NaN;
  const lat = typeof point?.lat === 'number' ? point.lat : Number.NaN;
  return Number.isFinite(lon) && Number.isFinite(lat) ? ({ lon, lat } satisfies LonLat) : undefined;
}

export type MapExitsOptions = {
  accesses: Record<string, unknown>[];
  accessRelations: Record<string, unknown>[];
  /** `zdaid → zdcid`, from {@link readStopAreaParents}. */
  stopAreaParents: ReadonlyMap<string, string>;
  /** Via stations that actually exist; an access to an unimported network is dropped. */
  knownStopIDs: ReadonlySet<string>;
};

export function mapExits({
  accesses,
  accessRelations,
  stopAreaParents,
  knownStopIDs,
}: MapExitsOptions) {
  const stopAreaByAccess = new Map<string, string>();
  for (const row of accessRelations as AccessRelationRow[]) {
    const accid = asString(row.accid);
    const zdaid = asString(row.zdaid);
    if (accid && zdaid) stopAreaByAccess.set(accid, zdaid);
  }

  const exits = new Map<string, MappedExit>();
  for (const row of accesses as AccessRow[]) {
    // `accisexit` is the referential's own string boolean, not a JSON one.
    if (asString(row.accisexit) !== 'true') continue;
    const accid = asString(row.accid);
    const name = asString(row.accname);
    const location = coordinateOf(row.accgeopoint);
    if (!accid || !name || !location) continue;

    const zdaid = stopAreaByAccess.get(accid);
    const zdcid = zdaid ? stopAreaParents.get(zdaid) : undefined;
    if (!zdcid) continue;
    const stopId = viaId(zdcid);
    if (!knownStopIDs.has(stopId)) continue;

    exits.set(viaId(accid), {
      id: viaId(accid),
      stopId,
      name,
      number: asInteger(row.accshortname) ?? null,
      detail: asString(row.accdescription) ?? null,
      location,
      source: EXIT_SOURCE,
      sourceRef: accid,
    });
  }
  return exits;
}

export type MapBoardingPositionsOptions = {
  trainPositions: Record<string, unknown>[];
  /** Ids of the exits {@link mapExits} kept, so a position can never dangle. */
  exitIDs: ReadonlySet<string>;
  /** Quay ids the GTFS import registered, i.e. `transit_stop_aliases`. */
  knownQuayIDs: ReadonlySet<string>;
};

export function mapBoardingPositions({
  trainPositions,
  exitIDs,
  knownQuayIDs,
}: MapBoardingPositionsOptions) {
  const positions = new Map<string, MappedBoardingPosition>();
  for (const row of trainPositions as TrainPositionRow[]) {
    const fromID = asString(row.from_id);
    const toID = asString(row.to_id);
    const lineID = asString(row.line_id);
    const car = asInteger(row.position);
    const carCount = asInteger(row.position_max);
    if (!fromID || !toID || !lineID || !car || !carCount) continue;
    // The check constraint would reject these inside the transaction, far from
    // the row that caused them.
    if (car < 1 || car > carCount) continue;

    const fromQuayId = viaId(fromID);
    if (asString(row.from_type) !== 'stop_point' || !knownQuayIDs.has(fromQuayId)) continue;

    const targetId = viaId(toID);
    const targetKind = asString(row.to_type) === 'access_point' ? 'exit' : 'transfer';
    const reachable = targetKind === 'exit' ? exitIDs.has(targetId) : knownQuayIDs.has(targetId);
    if (!reachable) continue;

    positions.set(`${fromQuayId}\u0000${targetId}`, {
      fromQuayId,
      targetId,
      targetKind,
      routeId: viaId(lineID),
      car,
      carCount,
      zone: zoneOf(asString(row.position_average), car, carCount),
      equipment: EQUIPMENT_BY_LABEL.get(asString(row.equipment_type) ?? '') ?? null,
      source: BOARDING_POSITION_SOURCE,
    });
  }
  return [...positions.values()];
}
