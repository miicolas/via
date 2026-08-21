import type { BoardingPosition, Coordinate, Journey, JourneyExit } from '@via/contract';
import { db } from '@via/db';
import { boardingPositions, stationExits } from '@via/db/schema';
import { inArray } from 'drizzle-orm';

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
 * Quay ids only come back from the realtime planner: Navitia reports
 * `stop_point:IDFM:463060` on each call, while the GTFS fallback resolves stops
 * to canonical stations. A station id simply matches no boarding position, so
 * the fallback degrades to exits alone with no special case.
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

export type WayfindingSnapshot = {
  /** Exits of a station, keyed by `transit_stops.id`. */
  exitsByStopId: ReadonlyMap<string, ExitRow[]>;
  /** Every boarding position leaving a quay, keyed by that quay. */
  positionsByQuayId: ReadonlyMap<string, PositionRow[]>;
  /** Raw planner stop id → canonical station id. */
  stationByStopId: ReadonlyMap<string, string>;
};

const EMPTY_SNAPSHOT: WayfindingSnapshot = {
  exitsByStopId: new Map(),
  positionsByQuayId: new Map(),
  stationByStopId: new Map(),
};

/** Boarding and alighting stop of every transit section, in section order. */
function transitEnds(journey: Journey) {
  return journey.sections.flatMap((section, index) => {
    if (section.type !== 'transit' || section.stops.length === 0) return [];
    return [{
      index,
      boardingStopId: section.stops[0]!.id,
      alightingStopId: section.stops.at(-1)!.id,
    }];
  });
}

export async function readWayfindingSnapshot(journeys: Journey[]): Promise<WayfindingSnapshot> {
  const ends = journeys.flatMap(transitEnds);
  if (ends.length === 0) return EMPTY_SNAPSHOT;

  const rawStopIDs = [...new Set(ends.flatMap((end) => [end.boardingStopId, end.alightingStopId]))];
  const quayIDs = [...new Set(rawStopIDs.map(bareStopId).filter((id) => id !== undefined))];
  const stationByStopId = await canonicalStationIDs(rawStopIDs);
  const stationIDs = [...new Set(stationByStopId.values())];

  const [exitRows, positionRows] = await Promise.all([
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

  return { exitsByStopId, positionsByQuayId, stationByStopId };
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
      ? positionsFrom(snapshot, end.alightingStopId)
        .find((row) => row.targetKind === 'transfer' && row.targetId === target)
      : undefined;
    if (position) boardingPositionByIndex.set(end.index, boardingPositionOf(position, 'transfer'));
  }

  // The last transit section: leave the network as close to the destination as possible.
  const last = ends.at(-1)!;
  const station = snapshot.stationByStopId.get(last.alightingStopId);
  const candidates = station ? snapshot.exitsByStopId.get(station) ?? [] : [];
  if (candidates.length > 0) {
    const positions = positionsFrom(snapshot, last.alightingStopId)
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
      const position = positions.find((row) => row.targetId === chosen.id);
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

function positionsFrom(snapshot: WayfindingSnapshot, rawStopId: string) {
  const quayId = bareStopId(rawStopId);
  return quayId ? snapshot.positionsByQuayId.get(quayId) ?? [] : [];
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
