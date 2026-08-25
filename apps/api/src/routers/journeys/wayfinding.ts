import type { BoardingPosition, Coordinate, Journey, JourneyExit } from '@via/contract';
import { db } from '@via/db';
import {
  boardingPositions,
  stationExits,
  transitRoutePatterns,
  transitRoutePatternStops,
} from '@via/db/schema';
import { and, asc, eq, inArray, isNotNull } from 'drizzle-orm';

import { haversineMeters } from '../../geo/distance';
import { bareStopId } from '../idfm/stop-ids';
import { canonicalStationIDs } from './accessibility';

/**
 * Turns "descendre ici" into "sortie 16, place du Châtelet, voiture 5 sur 5".
 *
 * Two facts, one lookup: the exit nearest the traveller's real destination, and
 * the carriage whose doors open in front of it. Both hang off the *quay* the
 * traveller arrives on — a station has one exit set but two opposite quays, and
 * carriage numbers count from the head of the train, so the same exit is
 * carriage 1 in one direction and carriage 5 in the other.
 *
 * Navitia usually reports a directional quay such as
 * `stop_point:IDFM:463060`. On RER sections it instead reports a monomodal
 * stop area that no quay-keyed row can match. Those sections fall back to the
 * rows the importer stamped with (station, route, GTFS direction): the leg's
 * penultimate call names the station the train came from, and the route's
 * patterns tell which direction visits the two in that order.
 */

type ExitRow = {
  id: string;
  stopId: string;
  name: string;
  number: number | null;
  coordinate: Coordinate;
};

type PositionRow = {
  fromQuayId: string;
  targetId: string;
  targetKind: 'exit' | 'transfer';
  car: number;
  carCount: number;
  zone: BoardingPosition['zone'];
  equipment: BoardingPosition['equipment'] | null;
};

type PatternStations = {
  directionId: number;
  stationIds: string[];
};

export type WayfindingSnapshot = {
  /** Exits of a station, keyed by `transit_stops.id`. */
  exitsByStopId: ReadonlyMap<string, ExitRow[]>;
  /** Every boarding position leaving a quay, keyed by that quay. */
  positionsByQuayId: ReadonlyMap<string, PositionRow[]>;
  /** Direction-resolved rows, keyed by {@link stationDirectionKey}. */
  positionsByStationDirection: ReadonlyMap<string, PositionRow[]>;
  /** Station sequences of every pattern of the journeys' routes, keyed by route. */
  patternsByRouteId: ReadonlyMap<string, PatternStations[]>;
  /** Raw planner stop id → canonical station id. */
  stationByStopId: ReadonlyMap<string, string>;
};

const EMPTY_SNAPSHOT: WayfindingSnapshot = {
  exitsByStopId: new Map(),
  positionsByQuayId: new Map(),
  positionsByStationDirection: new Map(),
  patternsByRouteId: new Map(),
  stationByStopId: new Map(),
};

/** Boarding, penultimate and alighting stop of every transit section, in order. */
function transitEnds(journey: Journey) {
  return journey.sections.flatMap((section, index) => {
    if (section.type !== 'transit' || section.stops.length === 0) return [];
    return [{
      index,
      routeId: section.route?.id,
      boardingStopId: section.stops[0]!.id,
      penultimateStopId: section.stops.at(-2)?.id,
      alightingStopId: section.stops.at(-1)!.id,
    }];
  });
}

type TransitEnd = ReturnType<typeof transitEnds>[number];

export async function readWayfindingSnapshot(journeys: Journey[]): Promise<WayfindingSnapshot> {
  const ends = journeys.flatMap(transitEnds);
  if (ends.length === 0) return EMPTY_SNAPSHOT;

  const rawStopIDs = [
    ...new Set(
      ends.flatMap((end) => [
        end.boardingStopId,
        end.alightingStopId,
        ...(end.penultimateStopId ? [end.penultimateStopId] : []),
      ])
    ),
  ];
  const quayIDs = [...new Set(rawStopIDs.map(bareStopId).filter((id) => id !== undefined))];
  const routeIDs = [...new Set(ends.flatMap((end) => (end.routeId ? [end.routeId] : [])))];
  const stationByStopId = await canonicalStationIDs(rawStopIDs);
  const stationIDs = [...new Set(stationByStopId.values())];

  const [exitRows, positionRows, directionalRows, patternRows] = await Promise.all([
    stationIDs.length === 0
      ? []
      : db
        .select({
          id: stationExits.id,
          stopId: stationExits.stopId,
          name: stationExits.name,
          number: stationExits.number,
          location: stationExits.location,
        })
        .from(stationExits)
        .where(inArray(stationExits.stopId, stationIDs)),
    quayIDs.length === 0
      ? []
      : db
        .select({
          fromQuayId: boardingPositions.fromQuayId,
          targetId: boardingPositions.targetId,
          targetKind: boardingPositions.targetKind,
          car: boardingPositions.car,
          carCount: boardingPositions.carCount,
          zone: boardingPositions.zone,
          equipment: boardingPositions.equipment,
        })
        .from(boardingPositions)
        .where(inArray(boardingPositions.fromQuayId, quayIDs)),
    stationIDs.length === 0
      ? []
      : db
        .select({
          fromQuayId: boardingPositions.fromQuayId,
          targetId: boardingPositions.targetId,
          targetKind: boardingPositions.targetKind,
          stationStopId: boardingPositions.stationStopId,
          routeId: boardingPositions.routeId,
          directionId: boardingPositions.directionId,
          car: boardingPositions.car,
          carCount: boardingPositions.carCount,
          zone: boardingPositions.zone,
          equipment: boardingPositions.equipment,
        })
        .from(boardingPositions)
        .where(
          and(
            inArray(boardingPositions.stationStopId, stationIDs),
            isNotNull(boardingPositions.directionId)
          )
        ),
    routeIDs.length === 0
      ? []
      : db
        .select({
          patternId: transitRoutePatternStops.patternId,
          routeId: transitRoutePatterns.routeId,
          directionId: transitRoutePatterns.directionId,
          stopId: transitRoutePatternStops.stopId,
        })
        .from(transitRoutePatternStops)
        .innerJoin(
          transitRoutePatterns,
          eq(transitRoutePatterns.id, transitRoutePatternStops.patternId)
        )
        .where(inArray(transitRoutePatterns.routeId, routeIDs))
        .orderBy(
          asc(transitRoutePatternStops.patternId),
          asc(transitRoutePatternStops.stopSequence)
        ),
  ]);

  const exitsByStopId = new Map<string, ExitRow[]>();
  for (const row of exitRows) {
    const exit: ExitRow = {
      id: row.id,
      stopId: row.stopId,
      name: row.name,
      number: row.number,
      coordinate: { latitude: row.location.lat, longitude: row.location.lon },
    };
    const bucket = exitsByStopId.get(row.stopId);
    if (bucket) bucket.push(exit);
    else exitsByStopId.set(row.stopId, [exit]);
  }

  const positionsByQuayId = new Map<string, PositionRow[]>();
  for (const row of positionRows) {
    const bucket = positionsByQuayId.get(row.fromQuayId);
    if (bucket) bucket.push(row);
    else positionsByQuayId.set(row.fromQuayId, [row]);
  }

  const positionsByStationDirection = new Map<string, PositionRow[]>();
  for (const row of directionalRows) {
    const key = stationDirectionKey(row.stationStopId!, row.routeId, row.directionId!);
    const bucket = positionsByStationDirection.get(key);
    if (bucket) bucket.push(row);
    else positionsByStationDirection.set(key, [row]);
  }

  const patternsByRouteId = new Map<string, PatternStations[]>();
  let pattern: (PatternStations & { patternId: string; routeId: string }) | undefined;
  for (const row of patternRows) {
    if (pattern?.patternId !== row.patternId) {
      pattern = {
        patternId: row.patternId,
        routeId: row.routeId,
        directionId: row.directionId,
        stationIds: [],
      };
      const bucket = patternsByRouteId.get(row.routeId);
      if (bucket) bucket.push(pattern);
      else patternsByRouteId.set(row.routeId, [pattern]);
    }
    pattern.stationIds.push(row.stopId);
  }

  return {
    exitsByStopId,
    positionsByQuayId,
    positionsByStationDirection,
    patternsByRouteId,
    stationByStopId,
  };
}

/**
 * Chooses the exit and the carriage for one journey. Pure, so the choice is
 * testable without a database.
 */
export function applyWayfinding(
  journey: Journey,
  destination: Coordinate,
  snapshot: WayfindingSnapshot
): Journey {
  const ends = transitEnds(journey);
  if (ends.length === 0) return journey;

  const boardingPositionByIndex = new Map<number, BoardingPosition>();
  const exitByIndex = new Map<number, JourneyExit>();

  // A connection: ride in the carriage that lands nearest the next line's quay.
  for (const [order, end] of ends.entries()) {
    const next = ends[order + 1];
    if (!next) continue;
    const target = bareStopId(next.boardingStopId);
    const position = target
      ? alightingPositions(snapshot, end)
        .find((row) => row.targetKind === 'transfer' && row.targetId === target)
      : undefined;
    if (position) boardingPositionByIndex.set(end.index, boardingPositionOf(position, 'transfer'));
  }

  // The last transit section: leave the network as close to the destination as possible.
  const last = ends.at(-1)!;
  const station = snapshot.stationByStopId.get(last.alightingStopId);
  const candidates = station ? snapshot.exitsByStopId.get(station) ?? [] : [];
  if (candidates.length > 0) {
    const positions = alightingPositions(snapshot, last)
      .filter((row) => row.targetKind === 'exit');
    // Exit choice is authoritative: always pick the closest one. Carriage
    // advice is additive and may be absent for that exit.
    const chosen = nearest(candidates, destination);
    if (chosen) {
      exitByIndex.set(last.index, {
        id: chosen.id,
        name: chosen.name,
        number: chosen.number ?? undefined,
        coordinate: chosen.coordinate,
        walkingMeters: Math.round(haversineMeters(chosen.coordinate, destination)),
      });
      const position = positions.find((row) => row.targetId === chosen.id)
        ?? exitConsensus(positions);
      if (position) boardingPositionByIndex.set(last.index, boardingPositionOf(position, 'exit'));
    }
  }

  if (boardingPositionByIndex.size === 0 && exitByIndex.size === 0) return journey;
  return {
    ...journey,
    sections: journey.sections.map((section, index) => {
      const boardingPosition = boardingPositionByIndex.get(index);
      const exit = exitByIndex.get(index);
      if (!boardingPosition && !exit) return section;
      return { ...section, ...(boardingPosition && { boardingPosition }), ...(exit && { exit }) };
    }),
  };
}

/**
 * The advice rows of the quay a section alights on: matched by quay id when
 * the planner named one, recovered from (station, route, direction) when it
 * collapsed the quay to a monomodal stop area.
 */
function alightingPositions(snapshot: WayfindingSnapshot, end: TransitEnd): PositionRow[] {
  const quayId = bareStopId(end.alightingStopId);
  const byQuay = (quayId ? snapshot.positionsByQuayId.get(quayId) : undefined) ?? [];

  // A direction-safe aggregate can coexist with richer direction-resolved
  // rows; the aggregate wins per target, the rest fills in around it.
  const covered = new Set(byQuay.map((row) => row.targetId));
  const byDirection = directionalPositions(snapshot, end)
    .filter((row) => !covered.has(row.targetId));
  return byDirection.length === 0 ? byQuay : [...byQuay, ...byDirection];
}

function directionalPositions(snapshot: WayfindingSnapshot, end: TransitEnd): PositionRow[] {
  const station = snapshot.stationByStopId.get(end.alightingStopId);
  const cameFrom = end.penultimateStopId
    ? snapshot.stationByStopId.get(end.penultimateStopId)
    : undefined;
  if (!station || !cameFrom || !end.routeId || station === cameFrom) return [];

  const directionId = travelDirection(
    snapshot.patternsByRouteId.get(end.routeId) ?? [],
    cameFrom,
    station
  );
  if (directionId === undefined) return [];
  return (
    snapshot.positionsByStationDirection.get(
      stationDirectionKey(station, end.routeId, directionId)
    ) ?? []
  );
}

/** The GTFS direction whose patterns visit `cameFrom` before `station`, if unambiguous. */
function travelDirection(patterns: readonly PatternStations[], cameFrom: string, station: string) {
  const directions = new Set<number>();
  for (const pattern of patterns) {
    const from = pattern.stationIds.indexOf(cameFrom);
    const to = pattern.stationIds.indexOf(station);
    if (from !== -1 && to !== -1 && from < to) directions.add(pattern.directionId);
  }
  if (directions.size !== 1) return undefined;
  return [...directions][0];
}

/**
 * The carriage every documented exit of the quay agrees on. An exit the source
 * skipped — Saint-Germain-en-Laye's « Hôtel de Ville » — then borrows that
 * unanimous advice: the doors still open next to a documented exit, so the
 * traveller lands close even if the signage differs. The equipment does not
 * cross over: it describes the walk to one specific exit.
 */
function exitConsensus(rows: PositionRow[]): PositionRow | undefined {
  const [first, ...rest] = rows;
  if (!first) return undefined;
  const unanimous = rest.every(
    (row) => row.car === first.car && row.carCount === first.carCount && row.zone === first.zone
  );
  return unanimous ? { ...first, equipment: null } : undefined;
}

function stationDirectionKey(stationStopId: string, routeId: string, directionId: number) {
  return [stationStopId, routeId, directionId].join(' ');
}

function boardingPositionOf(row: PositionRow, reason: BoardingPosition['reason']): BoardingPosition {
  return {
    car: row.car,
    carCount: row.carCount,
    zone: row.zone,
    reason,
    ...(row.equipment && { equipment: row.equipment }),
  };
}

function nearest(exits: ExitRow[], destination: Coordinate) {
  let best: ExitRow | undefined;
  let bestDistance = Number.POSITIVE_INFINITY;
  for (const exit of exits) {
    const distance = haversineMeters(exit.coordinate, destination);
    if (distance < bestDistance) {
      best = exit;
      bestDistance = distance;
    }
  }
  return best;
}

/** Annotates every journey of a planner response with its exit and carriage advice. */
export async function annotateWayfinding(journeys: Journey[], destination: Coordinate) {
  if (journeys.length === 0) return journeys;
  try {
    const snapshot = await readWayfindingSnapshot(journeys);
    return journeys.map((journey) => applyWayfinding(journey, destination, snapshot));
  } catch (cause) {
    // Advisory detail. A database hiccup costs the exit hint, never the itinerary.
    console.error('[journeys] annotation sorties/voiture indisponible', cause);
    return journeys;
  }
}
