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
  /** Referential `arrid → zdaid`, for planners that collapse rail quays to a stop area. */
  stopAreaByQuay?: ReadonlyMap<string, string>;
};

type BoardingCandidate = MappedBoardingPosition & {
  sourceQuayId: string;
  stopAreaId: string;
};

export function mapBoardingPositions({
  trainPositions,
  exitIDs,
  knownQuayIDs,
  stopAreaByQuay = new Map(),
}: MapBoardingPositionsOptions) {
  const positions = new Map<string, MappedBoardingPosition>();
  const aggregateCandidates: BoardingCandidate[] = [];
  const platformsByStopAreaAndRoute = new Map<string, Set<string>>();

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
    if (asString(row.from_type) !== 'stop_point') continue;

    const routeId = viaId(lineID);
    const stopAreaId = stopAreaByQuay.get(fromID);
    if (stopAreaId) {
      const groupKey = stopAreaRouteKey(stopAreaId, routeId);
      const platforms = platformsByStopAreaAndRoute.get(groupKey);
      if (platforms) platforms.add(fromID);
      else platformsByStopAreaAndRoute.set(groupKey, new Set([fromID]));
    }

    const targetId = viaId(toID);
    const targetKind = asString(row.to_type) === 'access_point' ? 'exit' : 'transfer';
    const reachable = targetKind === 'exit' ? exitIDs.has(targetId) : knownQuayIDs.has(targetId);
    if (!reachable) continue;

    const position: MappedBoardingPosition = {
      fromQuayId,
      targetId,
      targetKind,
      routeId,
      car,
      carCount,
      zone: zoneOf(asString(row.position_average), car, carCount),
      equipment: EQUIPMENT_BY_LABEL.get(asString(row.equipment_type) ?? '') ?? null,
      source: BOARDING_POSITION_SOURCE,
    };

    if (knownQuayIDs.has(fromQuayId)) positions.set(positionKey(position), position);
    if (stopAreaId && targetKind === 'exit') {
      aggregateCandidates.push({ ...position, sourceQuayId: fromID, stopAreaId });
    }
  }

  addDirectionSafeStopAreaPositions({
    positions,
    candidates: aggregateCandidates,
    platformsByStopAreaAndRoute,
    knownQuayIDs,
  });

  return [...positions.values()];
}

type AddStopAreaPositionsOptions = {
  positions: Map<string, MappedBoardingPosition>;
  candidates: BoardingCandidate[];
  platformsByStopAreaAndRoute: ReadonlyMap<string, ReadonlySet<string>>;
  knownQuayIDs: ReadonlySet<string>;
};

/**
 * RER sections can carry `monomodalStopPlace:<zdaid>` instead of a directional
 * quay. A station-level fallback is safe only when every source quay publishes
 * the same single car for the target; otherwise the direction must stay unknown.
 */
function addDirectionSafeStopAreaPositions({
  positions,
  candidates,
  platformsByStopAreaAndRoute,
  knownQuayIDs,
}: AddStopAreaPositionsOptions) {
  const candidatesByTarget = new Map<string, BoardingCandidate[]>();
  for (const candidate of candidates) {
    const key = `${stopAreaRouteKey(candidate.stopAreaId, candidate.routeId)}\u0000${candidate.targetId}`;
    const bucket = candidatesByTarget.get(key);
    if (bucket) bucket.push(candidate);
    else candidatesByTarget.set(key, [candidate]);
  }

  for (const targetCandidates of candidatesByTarget.values()) {
    const first = targetCandidates[0]!;
    const platforms = platformsByStopAreaAndRoute.get(
      stopAreaRouteKey(first.stopAreaId, first.routeId)
    );
    if (!platforms) continue;

    const choicesByPlatform = new Map<string, Set<string>>();
    for (const candidate of targetCandidates) {
      const choices = choicesByPlatform.get(candidate.sourceQuayId);
      if (choices) choices.add(choiceKey(candidate));
      else choicesByPlatform.set(candidate.sourceQuayId, new Set([choiceKey(candidate)]));
    }
    if (choicesByPlatform.size !== platforms.size) continue;

    const [firstChoices, ...otherChoices] = [...choicesByPlatform.values()];
    const commonChoices = [...firstChoices!].filter((choice) =>
      otherChoices.every((choices) => choices.has(choice))
    );
    if (commonChoices.length !== 1) continue;

    const commonChoice = commonChoices[0]!;
    const representative = targetCandidates.find(
      (candidate) => choiceKey(candidate) === commonChoice
    )!;
    const equipments = new Set(
      targetCandidates
        .filter((candidate) => choiceKey(candidate) === commonChoice)
        .map((candidate) => candidate.equipment)
    );
    const fromQuayId = viaId(`monomodalStopPlace:${first.stopAreaId}`);
    if (!knownQuayIDs.has(fromQuayId)) continue;

    const position: MappedBoardingPosition = {
      fromQuayId,
      targetId: representative.targetId,
      targetKind: representative.targetKind,
      routeId: representative.routeId,
      car: representative.car,
      carCount: representative.carCount,
      zone: representative.zone,
      equipment: equipments.size === 1 ? [...equipments][0]! : null,
      source: representative.source,
    };
    if (!positions.has(positionKey(position))) positions.set(positionKey(position), position);
  }
}

function stopAreaRouteKey(stopAreaId: string, routeId: string) {
  return `${stopAreaId}\u0000${routeId}`;
}

function positionKey(position: Pick<MappedBoardingPosition, 'fromQuayId' | 'targetId'>) {
  return `${position.fromQuayId}\u0000${position.targetId}`;
}

function choiceKey(
  position: Pick<MappedBoardingPosition, 'car' | 'carCount' | 'zone'>
) {
  return `${position.car}\u0000${position.carCount}\u0000${position.zone}`;
}
