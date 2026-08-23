import type { Coordinate } from '@via/contract';
import { db } from '@via/db';
import {
  networkMode,
  stationFacts,
  transitProfileStops,
  transitRoutes,
  transitServiceDates,
  transitShapes,
  transitStopRoutes,
  transitStops,
  transitTransfers,
  transitTrips,
} from '@via/db/schema';
import { absoluteTimetableSeconds } from '@via/db/timetable';
import { and, asc, desc, eq, gte, inArray, isNotNull, lte, sql } from 'drizzle-orm';

import { parisDay, previousDate } from '../../../time/paris';
import { readTimetableHorizon } from './timetable-horizon';
import type { GtfsJourneyPlanner } from '../service';
import { plannerTripKey, planWithGtfs } from './planner';
import type {
  GtfsPlannerLoader,
  PlannerAlighting,
  PlannerBoarding,
  PlannerCall,
  PlannerStop,
  PlannerTrip,
  PlannerReverseTransfer,
  PlannerTransfer,
} from './planner';

const MAX_BOARDINGS_PER_STOP = 32;
const MAX_BOARDING_CANDIDATES = 1_500;

/** 'board' walks departures forward in time; 'alight' walks arrivals backward. */
export type StopTimeDirection = 'board' | 'alight';

type StopTimeCandidate = {
  tripId: string;
  stopKey: number;
  seconds: number;
  serviceDate: string;
};

/**
 * Whether yesterday's service day can still contain a boarding this search
 * would accept — asked before spending a query to find out.
 *
 * A GTFS service day runs past midnight, so yesterday's late trips are read in
 * yesterday's frame: a departure at or after `bound` today is at or after
 * `bound + 86 400` there. The feed's own horizon (measured at import) is the
 * latest second any call reaches, so once `bound + 86 400` passes it the
 * query's WHERE clause is unsatisfiable — it scans ~114 000 rows across the
 * frontier's stops to return nothing, 183 ms at a time, three times per plan.
 * With the current IDFM feed topping out at 32:00 that is every search after
 * 08:00, which is most of the traffic.
 *
 * Only the forward direction is decided here. `alight` walks arrivals backward
 * with `secs <= bound + 86 400`, which stays satisfiable — yesterday returns
 * rows that are merely useless rather than absent, and dropping them would
 * change which labels the planner explores rather than just how fast it gets
 * there. An unknown horizon keeps both days, the behaviour that predates this.
 */
export function yesterdayIsSearchable(
  direction: StopTimeDirection,
  bound: number,
  horizonSeconds: number
) {
  if (direction !== 'board') return true;
  return bound + 86_400 <= horizonSeconds;
}

async function yesterdayCanStillBeRunning(direction: StopTimeDirection, bound: number) {
  if (direction !== 'board') return true;
  return yesterdayIsSearchable(direction, bound, await readTimetableHorizon());
}

export function createGtfsLoader(now: Date, requiresAccessibleStations = false): GtfsPlannerLoader {
  const { date } = parisDay(now);
  const yesterday = previousDate(date);
  const stopCache = new Map<string, PlannerStop>();
  const stopKeyById = new Map<string, number>();
  const stopIdByKey = new Map<number, string>();
  let activeServiceIdsByDate: Promise<Map<string, string[]>> | undefined;

  const activeServices = (serviceDates: string[]) => {
    activeServiceIdsByDate ??= db
      .select({ serviceId: transitServiceDates.serviceId, date: transitServiceDates.date })
      .from(transitServiceDates)
      .where(inArray(transitServiceDates.date, serviceDates))
      .then((rows) => {
        const grouped = Map.groupBy(rows, (row) => row.date);
        return new Map(
          [...grouped].map(([serviceDate, entries]) => [
            serviceDate,
            entries.map((entry) => entry.serviceId),
          ])
        );
      });
    return activeServiceIdsByDate;
  };

  const stopTimeEvents = async (
    direction: StopTimeDirection,
    stopIds: string[],
    boundByStop: Map<string, number>,
    serviceDates: string[]
  ) => {
    if (stopIds.length === 0) return [];
    const stopKeys = stopIds.flatMap((id) => {
      const key = stopKeyById.get(id);
      return key === undefined ? [] : [key];
    });
    if (stopKeys.length === 0) return [];
    const bound =
      direction === 'board' ? Math.min(...boundByStop.values()) : Math.max(...boundByStop.values());
    const services = await activeServices(serviceDates);
    const todayRows = await loadStopTimeCandidates(
      direction,
      stopKeys,
      services.get(date) ?? [],
      bound,
      date,
      0
    );
    const yesterdayRows = (await yesterdayCanStillBeRunning(direction, bound))
      ? await loadStopTimeCandidates(
          direction,
          stopKeys,
          services.get(yesterday) ?? [],
          bound + 86_400,
          yesterday,
          -86_400
        )
      : [];
    const rows = [...todayRows, ...yesterdayRows]
      .sort((a, b) => (direction === 'board' ? a.seconds - b.seconds : b.seconds - a.seconds))
      .slice(0, MAX_BOARDING_CANDIDATES);

    const counts = new Map<string, number>();
    return rows.flatMap((row) => {
      const stopId = stopIdByKey.get(row.stopKey);
      if (!stopId) return [];
      const outOfBound =
        direction === 'board'
          ? row.seconds < (boundByStop.get(stopId) ?? Infinity)
          : row.seconds > (boundByStop.get(stopId) ?? -Infinity);
      if (outOfBound) return [];
      const count = counts.get(stopId) ?? 0;
      if (count >= MAX_BOARDINGS_PER_STOP) return [];
      counts.set(stopId, count + 1);
      return [{ tripId: row.tripId, stopId, seconds: row.seconds, serviceDate: row.serviceDate }];
    });
  };

  const loadTransfers = async (anchorStopIds: string[], hydrate: 'to' | 'from') => {
    if (anchorStopIds.length === 0) return [];
    const hydratedColumn =
      hydrate === 'to' ? transitTransfers.toStopId : transitTransfers.fromStopId;
    const anchorColumn = hydrate === 'to' ? transitTransfers.fromStopId : transitTransfers.toStopId;
    const rows = await db
      .select({
        fromStopId: transitTransfers.fromStopId,
        toStopId: transitTransfers.toStopId,
        minTransferSeconds: transitTransfers.minTransferSeconds,
        numericId: transitStops.numericId,
        name: transitStops.name,
        coordinate: sql<Coordinate>`json_build_object(
          'latitude', ST_Y(${transitStops.location}),
          'longitude', ST_X(${transitStops.location})
        )`,
        accessibilityStopId: stationFacts.stopId,
      })
      .from(transitTransfers)
      .innerJoin(transitStops, eq(transitStops.id, hydratedColumn))
      .leftJoin(
        stationFacts,
        and(eq(stationFacts.stopId, hydratedColumn), eq(stationFacts.kind, 'accessibility'))
      )
      .where(
        and(
          inArray(anchorColumn, anchorStopIds),
          requiresAccessibleStations ? isNotNull(stationFacts.stopId) : undefined
        )
      );
    return rows.map((row) => {
      const stop = {
        id: hydrate === 'to' ? row.toStopId : row.fromStopId,
        name: row.name,
        coordinate: row.coordinate,
        isAccessible: row.accessibilityStopId !== null,
      };
      stopCache.set(stop.id, stop);
      stopKeyById.set(stop.id, row.numericId);
      stopIdByKey.set(row.numericId, stop.id);
      return { row, stop };
    });
  };

  return {
    accessStops: async (coordinate, limit, stationId) => {
      const rows = await db
        .select({
          id: transitStops.id,
          numericId: transitStops.numericId,
          name: transitStops.name,
          coordinate: sql<Coordinate>`json_build_object(
            'latitude', ST_Y(${transitStops.location}),
            'longitude', ST_X(${transitStops.location})
          )`,
        })
        .from(transitStops)
        .innerJoin(transitStopRoutes, eq(transitStopRoutes.stopId, transitStops.id))
        .leftJoin(
          stationFacts,
          and(eq(stationFacts.stopId, transitStops.id), eq(stationFacts.kind, 'accessibility'))
        )
        .where(
          and(
            sql`ST_DWithin(
              ${transitStops.location}::geography,
              ST_SetSRID(ST_MakePoint(${coordinate.longitude}, ${coordinate.latitude}), 4326)::geography,
              3_000
            )`,
            stationId ? eq(transitStops.id, stationId) : undefined,
            requiresAccessibleStations ? isNotNull(stationFacts.stopId) : undefined
          )
        )
        .groupBy(transitStops.id, transitStops.name, transitStops.location)
        .orderBy(
          sql`ST_Distance(
            ${transitStops.location}::geography,
            ST_SetSRID(ST_MakePoint(${coordinate.longitude}, ${coordinate.latitude}), 4326)::geography
          )`
        )
        .limit(limit);

      return rows.map((row) => {
        const stop = {
          id: row.id,
          name: row.name,
          coordinate: row.coordinate,
          isAccessible: requiresAccessibleStations,
        };
        stopCache.set(stop.id, stop);
        stopKeyById.set(stop.id, row.numericId);
        stopIdByKey.set(row.numericId, stop.id);
        return stop;
      });
    },

    boardings: async (stopIds, earliestByStop, serviceDates) =>
      (await stopTimeEvents('board', stopIds, earliestByStop, serviceDates)).map(
        ({ seconds, ...event }): PlannerBoarding => ({ ...event, departureSeconds: seconds })
      ),

    alightings: async (stopIds, latestByStop, serviceDates) =>
      (await stopTimeEvents('alight', stopIds, latestByStop, serviceDates)).map(
        ({ seconds, ...event }): PlannerAlighting => ({ ...event, arrivalSeconds: seconds })
      ),

    trips: async (boardings) => {
      const tripIds = [...new Set(boardings.map((boarding) => boarding.tripId))];
      if (tripIds.length === 0) return new Map();

      const tripRows = await db
        .select({
          numericId: transitTrips.numericId,
          id: transitTrips.id,
          headsign: transitTrips.headsign,
          shapeId: transitTrips.shapeId,
          routeId: transitRoutes.id,
          shortName: transitRoutes.shortName,
          longName: transitRoutes.longName,
          routeType: transitRoutes.routeType,
          color: transitRoutes.color,
          textColor: transitRoutes.textColor,
        })
        .from(transitTrips)
        .innerJoin(transitRoutes, eq(transitRoutes.id, transitTrips.routeId))
        .where(inArray(transitTrips.id, tripIds));

      const numericIds = tripRows.map((trip) => trip.numericId);
      const callRows = numericIds.length
        ? await db
            .select({
              tripKey: transitTrips.numericId,
              stopId: transitStops.id,
              stopNumericId: transitStops.numericId,
              stopSequence: transitProfileStops.position,
              arrivalSeconds: absoluteTimetableSeconds(transitProfileStops.arrivalOffset),
              departureSeconds: absoluteTimetableSeconds(transitProfileStops.departureOffset),
              name: transitStops.name,
              coordinate: sql<Coordinate>`json_build_object(
                'latitude', ST_Y(${transitStops.location}),
                'longitude', ST_X(${transitStops.location})
              )`,
              accessibilityStopId: stationFacts.stopId,
            })
            .from(transitTrips)
            .innerJoin(
              transitProfileStops,
              eq(transitProfileStops.profileKey, transitTrips.profileKey)
            )
            .innerJoin(transitStops, eq(transitStops.numericId, transitProfileStops.stopKey))
            .leftJoin(
              stationFacts,
              and(eq(stationFacts.stopId, transitStops.id), eq(stationFacts.kind, 'accessibility'))
            )
            .where(inArray(transitTrips.numericId, numericIds))
            .orderBy(asc(transitTrips.numericId), asc(transitProfileStops.position))
        : [];

      const callsByTrip = Map.groupBy(callRows, (call) => call.tripKey);
      const tripById = new Map(tripRows.map((trip) => [trip.id, trip]));
      const loaded = new Map<string, { trip: PlannerTrip; calls: PlannerCall[] }>();

      for (const boarding of boardings) {
        const key = plannerTripKey(boarding.tripId, boarding.serviceDate);
        if (loaded.has(key)) continue;
        const tripRow = tripById.get(boarding.tripId);
        if (!tripRow) continue;
        const mode = networkMode(tripRow.routeType, tripRow.shortName);
        if (!mode) continue;
        const offset = boarding.serviceDate === yesterday ? -86_400 : 0;
        const calls = (callsByTrip.get(tripRow.numericId) ?? []).map((call): PlannerCall => {
          const stop = stopCache.get(call.stopId) ?? {
            id: call.stopId,
            name: call.name,
            coordinate: call.coordinate,
            isAccessible: call.accessibilityStopId !== null,
          };
          stopCache.set(stop.id, stop);
          stopKeyById.set(stop.id, call.stopNumericId);
          stopIdByKey.set(call.stopNumericId, stop.id);
          return {
            stop,
            stopSequence: call.stopSequence,
            arrivalSeconds: call.arrivalSeconds + offset,
            departureSeconds: call.departureSeconds + offset,
            serviceDate: boarding.serviceDate,
          };
        });
        loaded.set(key, {
          trip: {
            id: tripRow.id,
            headsign: tripRow.headsign,
            shapeId: tripRow.shapeId ?? undefined,
            route: {
              id: tripRow.routeId,
              shortName: tripRow.shortName,
              longName: tripRow.longName,
              mode,
              color: normalizeColor(tripRow.color),
              textColor: normalizeColor(tripRow.textColor),
            },
          },
          calls,
        });
      }
      return loaded;
    },

    shapes: async (shapeIds) => {
      if (shapeIds.length === 0) return new Map();
      const rows = await db
        .select({ id: transitShapes.id, geometry: transitShapes.geometry })
        .from(transitShapes)
        .where(inArray(transitShapes.id, shapeIds));
      return new Map(
        rows.map((row) => [
          row.id,
          (row.geometry ?? []).map(({ lat, lon }) => ({ latitude: lat, longitude: lon })),
        ])
      );
    },

    transfers: async (stopIds) =>
      (await loadTransfers(stopIds, 'to')).map(
        ({ row, stop }): PlannerTransfer => ({
          fromStopId: row.fromStopId,
          toStop: stop,
          minTransferSeconds: row.minTransferSeconds,
        })
      ),

    reverseTransfers: async (stopIds) =>
      (await loadTransfers(stopIds, 'from')).map(
        ({ row, stop }): PlannerReverseTransfer => ({
          fromStop: stop,
          toStopId: row.toStopId,
          minTransferSeconds: row.minTransferSeconds,
        })
      ),
  };
}

/** Production adapter joining the Postgres loader to the pure GTFS planner. */
export function createGtfsJourneyPlanner(): GtfsJourneyPlanner {
  return {
    plan: async (input, now, signal) => {
      signal?.throwIfAborted();
      const response = await planWithGtfs(
        input.origin,
        input.destination,
        now,
        input.limit,
        createGtfsLoader(now, input.requiresAccessibleStations),
        input.datetimeRepresents ?? 'departure',
        input.requiresAccessibleStations,
        input.originStationId
      );
      signal?.throwIfAborted();
      return response;
    },
  };
}

async function loadStopTimeCandidates(
  direction: StopTimeDirection,
  stopKeys: number[],
  activeServiceIds: string[],
  boundSeconds: number,
  serviceDate: string,
  offset: number
): Promise<StopTimeCandidate[]> {
  if (activeServiceIds.length === 0) return [];
  const offsetColumn =
    direction === 'board'
      ? transitProfileStops.departureOffset
      : transitProfileStops.arrivalOffset;
  const column = absoluteTimetableSeconds(offsetColumn);
  const rows = await db
    .select({
      tripId: transitTrips.id,
      stopKey: transitProfileStops.stopKey,
      seconds: column,
    })
    .from(transitProfileStops)
    .innerJoin(transitTrips, eq(transitTrips.profileKey, transitProfileStops.profileKey))
    .where(
      and(
        inArray(transitProfileStops.stopKey, stopKeys),
        inArray(transitTrips.serviceId, activeServiceIds),
        direction === 'board' ? gte(column, boundSeconds) : lte(column, boundSeconds)
      )
    )
    .orderBy(direction === 'board' ? asc(column) : desc(column))
    .limit(MAX_BOARDING_CANDIDATES);
  return rows.map((row) => ({
    ...row,
    seconds: row.seconds + offset,
    serviceDate,
  }));
}

function normalizeColor(value: string) {
  return value.startsWith('#') ? value : `#${value}`;
}
