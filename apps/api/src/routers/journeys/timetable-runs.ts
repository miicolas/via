import { db } from '@via/db';
import {
  transitProfileStops,
  transitServiceDates,
  transitStopAliases,
  transitStops,
  transitTrips,
} from '@via/db/schema';
import { absoluteTimetableSeconds } from '@via/db/timetable';
import { aliasedTable, and, asc, eq, gt, gte, inArray, lte } from 'drizzle-orm';

import { parisDay, previousDate, toInstant } from '../../time/paris';

/** One scheduled run of a line between two of its stops. */
export type TimetableRun = {
  tripId: string;
  headsign: string;
  departureAt: string;
  arrivalAt: string;
};

export type TimetableRunQuery = {
  routeId: string;
  /** Candidate ids for the boarding stop, in preference order. */
  boardingStopIds: string[];
  /** Candidate ids for the alighting stop, in preference order. */
  alightingStopIds: string[];
  from: Date;
  to: Date;
  limit?: number;
};

/**
 * The other passages of a line the traveller could take instead, read from the
 * timetable rather than discovered by planning.
 *
 * Asking the planner "what else leaves around now" cannot answer this: it
 * prunes every itinerary a faster one dominates, and a later train on the very
 * same line arriving later for no fewer transfers is exactly what that prunes.
 * The schedule has no such opinion — it simply lists the runs — so enumeration
 * belongs here and only the chosen run is planned.
 */
export type TimetableRunReader = (query: TimetableRunQuery) => Promise<TimetableRun[]>;

const DEFAULT_LIMIT = 24;

export const selectTimetableRuns: TimetableRunReader = async (query) => {
  const [boardingStopId, alightingStopId] = await Promise.all([
    canonicalStopId(query.boardingStopIds),
    canonicalStopId(query.alightingStopIds),
  ]);
  if (!boardingStopId || !alightingStopId || boardingStopId === alightingStopId) return [];

  const limit = query.limit ?? DEFAULT_LIMIT;
  const { date, seconds } = parisDay(query.from);
  const windowSeconds = Math.max(
    0,
    Math.round((query.to.getTime() - query.from.getTime()) / 1_000)
  );
  const yesterdayDate = previousDate(date);

  // Two service days, for the same reason the departure board consults two: at
  // 00:30 the trains still running belong to yesterday's service, recorded as
  // "24:30".
  const [today, yesterday] = await Promise.all([
    runRows(
      { routeId: query.routeId, boardingStopId, alightingStopId },
      date,
      seconds,
      seconds + windowSeconds,
      limit
    ),
    runRows(
      { routeId: query.routeId, boardingStopId, alightingStopId },
      yesterdayDate,
      seconds + 86_400,
      seconds + 86_400 + windowSeconds,
      limit
    ),
  ]);

  return [
    ...yesterday.map((row) => toRun(row, yesterdayDate)),
    ...today.map((row) => toRun(row, date)),
  ]
    .sort((a, b) => a.departureAt.localeCompare(b.departureAt))
    .slice(0, limit);
};

type RunRow = {
  tripId: string;
  headsign: string;
  departureSeconds: number;
  arrivalSeconds: number;
};

function toRun(row: RunRow, serviceDate: string): TimetableRun {
  return {
    tripId: row.tripId,
    headsign: row.headsign,
    departureAt: toInstant(serviceDate, row.departureSeconds),
    arrivalAt: toInstant(serviceDate, row.arrivalSeconds),
  };
}

async function runRows(
  target: { routeId: string; boardingStopId: string; alightingStopId: string },
  serviceDate: string,
  fromSeconds: number,
  toSeconds: number,
  limit: number
): Promise<RunRow[]> {
  const boarding = aliasedTable(transitProfileStops, 'boarding_call');
  const alighting = aliasedTable(transitProfileStops, 'alighting_call');
  const boardingStop = aliasedTable(transitStops, 'boarding_stop');
  const alightingStop = aliasedTable(transitStops, 'alighting_stop');
  const departureSeconds = absoluteTimetableSeconds(boarding.departureOffset);
  const arrivalSeconds = absoluteTimetableSeconds(alighting.arrivalOffset);

  return db
    .select({
      tripId: transitTrips.id,
      headsign: transitTrips.headsign,
      departureSeconds,
      arrivalSeconds,
    })
    .from(boarding)
    .innerJoin(transitTrips, eq(transitTrips.profileKey, boarding.profileKey))
    // The alighting stop must be called *after* the boarding one: the same
    // physical line calls at both stops in each direction, and only the order
    // tells the two apart.
    .innerJoin(
      alighting,
      and(eq(alighting.profileKey, boarding.profileKey), gt(alighting.position, boarding.position))
    )
    .innerJoin(boardingStop, eq(boardingStop.numericId, boarding.stopKey))
    .innerJoin(alightingStop, eq(alightingStop.numericId, alighting.stopKey))
    .innerJoin(transitServiceDates, eq(transitServiceDates.serviceId, transitTrips.serviceId))
    .where(
      and(
        eq(boardingStop.id, target.boardingStopId),
        eq(alightingStop.id, target.alightingStopId),
        eq(transitTrips.routeId, target.routeId),
        eq(transitServiceDates.date, serviceDate),
        gte(departureSeconds, fromSeconds),
        lte(departureSeconds, toSeconds)
      )
    )
    .orderBy(asc(departureSeconds))
    .limit(limit);
}

/**
 * Whatever a journey calls a stop, folded back to the id the timetable uses.
 * IDFM answers in Navitia ids (`stop_area:IDFM:71264`), the GTFS planner in our
 * own (`IDFM:71264`); the alias table is what reconciles them.
 */
async function canonicalStopId(candidates: string[]): Promise<string | undefined> {
  const ids = [...new Set(candidates.filter((id) => id.length > 0))];
  if (ids.length === 0) return undefined;

  const [direct, aliased] = await Promise.all([
    db.select({ id: transitStops.id }).from(transitStops).where(inArray(transitStops.id, ids)),
    db
      .select({ sourceId: transitStopAliases.sourceId, id: transitStopAliases.stopId })
      .from(transitStopAliases)
      .where(inArray(transitStopAliases.sourceId, ids)),
  ]);

  const resolved = new Map<string, string>();
  for (const row of aliased) resolved.set(row.sourceId, row.id);
  // A stop that *is* a timetable stop answers for itself, whatever an alias says.
  for (const row of direct) resolved.set(row.id, row.id);

  // The caller's order is its preference — the station area before the platform.
  return candidates.map((candidate) => resolved.get(candidate)).find(Boolean);
}
