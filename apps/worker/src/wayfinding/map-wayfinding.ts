import type {
  BoardingPositionEquipment,
  BoardingPositionZone,
  LonLat,
} from '@via/db/schema';

import { asInteger, asString, viaId } from '../idfm/referential';
import { inferQuayDirection, type TravelVector } from './quay-directions';

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
  /** Canonical Via station of the arrival quay, when the referential resolves it. */
  stationStopId: string | null;
  /** GTFS direction the quay serves, when the inference could tell; see quay-directions.ts. */
  directionId: number | null;
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
  /** `zdaid → canonical Via station id`, for stations the GTFS import created. */
  stationByStopArea?: ReadonlyMap<string, string>;
  /** Exit coordinates, so the direction of a referential-only quay can be inferred. */
  exitLocationById?: ReadonlyMap<string, LonLat>;
  stationLocationByStopId?: ReadonlyMap<string, LonLat>;
  /** {@link stationRouteKey} → travel vectors, one per GTFS direction of the route. */
  travelVectorsByStationRoute?: ReadonlyMap<string, readonly TravelVector[]>;
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
  stationByStopArea = new Map(),
  exitLocationById = new Map(),
  stationLocationByStopId = new Map(),
  travelVectorsByStationRoute = new Map(),
}: MapBoardingPositionsOptions) {
  const positions = new Map<string, MappedBoardingPosition>();
  const aggregateCandidates: BoardingCandidate[] = [];
  const referentialQuayRows = new Map<string, MappedBoardingPosition[]>();
  const stationLevelTransfers: MappedBoardingPosition[] = [];
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
    const stationStopId = stopAreaId ? stationByStopArea.get(stopAreaId) ?? null : null;
    if (stopAreaId) {
      const groupKey = stopAreaRouteKey(stopAreaId, routeId);
      const platforms = platformsByStopAreaAndRoute.get(groupKey);
      if (platforms) platforms.add(fromID);
      else platformsByStopAreaAndRoute.set(groupKey, new Set([fromID]));
    }

    const targetKind = asString(row.to_type) === 'access_point' ? 'exit' : 'transfer';
    // A transfer normally aims at the next line's quay. When that quay only
    // exists in the referential — an RER platform — it is renamed to the
    // monomodal stop area the planner will actually report, so the reader can
    // still equate the two. Those renamed rows merge two platforms into one
    // station and are only kept when they do not disagree.
    let targetId = viaId(toID);
    let isStationLevelTarget = false;
    if (targetKind === 'transfer' && !knownQuayIDs.has(targetId)) {
      const targetStopArea = stopAreaByQuay.get(toID);
      const monomodalId = targetStopArea
        ? viaId(`monomodalStopPlace:${targetStopArea}`)
        : undefined;
      if (!monomodalId || !knownQuayIDs.has(monomodalId)) continue;
      targetId = monomodalId;
      isStationLevelTarget = true;
    }
    if (targetKind === 'exit' && !exitIDs.has(targetId)) continue;

    const position: MappedBoardingPosition = {
      fromQuayId,
      targetId,
      targetKind,
      routeId,
      stationStopId,
      directionId: null,
      car,
      carCount,
      zone: zoneOf(asString(row.position_average), car, carCount),
      equipment: EQUIPMENT_BY_LABEL.get(asString(row.equipment_type) ?? '') ?? null,
      source: BOARDING_POSITION_SOURCE,
    };

    if (knownQuayIDs.has(fromQuayId)) {
      if (isStationLevelTarget) stationLevelTransfers.push(position);
      else positions.set(positionKey(position), position);
    } else if (stationStopId) {
      // A quay only the referential knows — an RER platform. Kept aside until
      // the direction inference below can tell which way its trains run.
      const bucket = referentialQuayRows.get(fromQuayId);
      if (bucket) bucket.push(position);
      else referentialQuayRows.set(fromQuayId, [position]);
    }
    if (stopAreaId && targetKind === 'exit') {
      aggregateCandidates.push({ ...position, sourceQuayId: fromID, stopAreaId });
    }
  }

  addInferredDirectionPositions({
    positions,
    referentialQuayRows,
    stationLevelTransfers,
    exitLocationById,
    stationLocationByStopId,
    travelVectorsByStationRoute,
  });
  addAgreedStationLevelTransfers(positions, stationLevelTransfers);
  addDirectionSafeStopAreaPositions({
    positions,
    candidates: aggregateCandidates,
    platformsByStopAreaAndRoute,
    knownQuayIDs,
    stationByStopArea,
  });

  return [...positions.values()];
}

type AddInferredDirectionOptions = {
  positions: Map<string, MappedBoardingPosition>;
  referentialQuayRows: ReadonlyMap<string, MappedBoardingPosition[]>;
  stationLevelTransfers: MappedBoardingPosition[];
  exitLocationById: ReadonlyMap<string, LonLat>;
  stationLocationByStopId: ReadonlyMap<string, LonLat>;
  travelVectorsByStationRoute: ReadonlyMap<string, readonly TravelVector[]>;
};

/**
 * Emits the rows of referential-only quays whose direction the geometry could
 * prove, stamped with (station, direction) so the reader can find them from a
 * monomodal planner stop. A quay the inference cannot resolve contributes
 * nothing here; the direction-safe aggregate below remains its only chance.
 */
function addInferredDirectionPositions({
  positions,
  referentialQuayRows,
  stationLevelTransfers,
  exitLocationById,
  stationLocationByStopId,
  travelVectorsByStationRoute,
}: AddInferredDirectionOptions) {
  for (const rows of referentialQuayRows.values()) {
    const first = rows[0]!;
    const stationLocation = stationLocationByStopId.get(first.stationStopId!);
    const travelVectors = travelVectorsByStationRoute.get(
      stationRouteKey(first.stationStopId!, first.routeId)
    );
    if (!stationLocation || !travelVectors) continue;

    const directionId = inferQuayDirection({
      stationLocation,
      travelVectors,
      advice: rows.flatMap((row) => {
        const exitLocation =
          row.targetKind === 'exit' ? exitLocationById.get(row.targetId) : undefined;
        return exitLocation ? [{ car: row.car, carCount: row.carCount, exitLocation }] : [];
      }),
    });
    if (directionId === undefined) continue;

    for (const row of rows) {
      const directed = { ...row, directionId };
      if (row.targetKind === 'transfer' && row.targetId.includes('monomodalStopPlace:')) {
        stationLevelTransfers.push(directed);
      } else {
        positions.set(positionKey(directed), directed);
      }
    }
  }
}

/**
 * Station-level transfer targets merged two platforms of the next line into
 * one id, so the advice of one platform could silently overwrite the other's.
 * Only unanimous groups survive; equipment survives only when unanimous too.
 */
function addAgreedStationLevelTransfers(
  positions: Map<string, MappedBoardingPosition>,
  candidates: readonly MappedBoardingPosition[]
) {
  const groups = new Map<string, MappedBoardingPosition[]>();
  for (const candidate of candidates) {
    const key = positionKey(candidate);
    const bucket = groups.get(key);
    if (bucket) bucket.push(candidate);
    else groups.set(key, [candidate]);
  }

  for (const [key, group] of groups) {
    const choices = new Set(group.map((candidate) => choiceKey(candidate)));
    if (choices.size !== 1) continue;
    const equipments = new Set(group.map((candidate) => candidate.equipment));
    positions.set(key, {
      ...group[0]!,
      equipment: equipments.size === 1 ? [...equipments][0]! : null,
    });
  }
}

type AddStopAreaPositionsOptions = {
  positions: Map<string, MappedBoardingPosition>;
  candidates: BoardingCandidate[];
  platformsByStopAreaAndRoute: ReadonlyMap<string, ReadonlySet<string>>;
  knownQuayIDs: ReadonlySet<string>;
  stationByStopArea: ReadonlyMap<string, string>;
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
  stationByStopArea,
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
      stationStopId: stationByStopArea.get(first.stopAreaId) ?? null,
      directionId: null,
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

/** Key of {@link MapBoardingPositionsOptions.travelVectorsByStationRoute}. */
export function stationRouteKey(stationStopId: string, routeId: string) {
  return [stationStopId, routeId].join(' ');
}

function positionKey(position: Pick<MappedBoardingPosition, 'fromQuayId' | 'targetId'>) {
  return `${position.fromQuayId}\u0000${position.targetId}`;
}

function choiceKey(
  position: Pick<MappedBoardingPosition, 'car' | 'carCount' | 'zone'>
) {
  return `${position.car}\u0000${position.carCount}\u0000${position.zone}`;
}
