import type { Coordinate } from '@via/contract';
import { db } from '@via/db';
import {
  networkMode,
  transitRoutes,
  transitServiceDates,
  transitShapes,
  transitStopRoutes,
  transitStops,
  transitTransfers,
  transitTripStopTimes,
  transitTrips,
} from '@via/db/schema';
import { and, asc, eq, gte, inArray, sql } from 'drizzle-orm';

import { previousDate, parisServiceDay } from '../../departures/theoretical/service-day';
import { plannerTripKey } from './planner';
import type {
  GtfsPlannerLoader,
  PlannerBoarding,
  PlannerCall,
  PlannerStop,
  PlannerTrip,
  PlannerTransfer,
} from './planner';

const MAX_BOARDINGS_PER_STOP = 32;
const MAX_BOARDING_CANDIDATES = 1_500;

type BoardingCandidate = {
  tripId: string;
  stopKey: number;
  departureSeconds: number;
  serviceDate: string;
};

export function createGtfsLoader(now: Date): GtfsPlannerLoader {
  const { date } = parisServiceDay(now);
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

  return {
    accessStops: async (coordinate, limit) => {
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
        .where(
          sql`ST_DWithin(
            ${transitStops.location}::geography,
            ST_SetSRID(ST_MakePoint(${coordinate.longitude}, ${coordinate.latitude}), 4326)::geography,
            3_000
          )`
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
        const stop = { id: row.id, name: row.name, coordinate: row.coordinate };
        stopCache.set(stop.id, stop);
        stopKeyById.set(stop.id, row.numericId);
        stopIdByKey.set(row.numericId, stop.id);
        return stop;
      });
    },

    boardings: async (stopIds, earliestByStop, serviceDates) => {
      if (stopIds.length === 0) return [];
      const stopKeys = stopIds.flatMap((id) => {
        const key = stopKeyById.get(id);
        return key === undefined ? [] : [key];
      });
      if (stopKeys.length === 0) return [];
      const minimum = Math.min(...earliestByStop.values());
      const services = await activeServices(serviceDates);
      const rows = (
        await Promise.all([
          loadBoardingCandidates(
            stopKeys,
            services.get(date) ?? [],
            minimum,
            date,
            0
          ),
          loadBoardingCandidates(
            stopKeys,
            services.get(yesterday) ?? [],
            minimum + 86_400,
            yesterday,
            -86_400
          ),
        ])
      )
        .flat()
        .sort((a, b) => a.departureSeconds - b.departureSeconds)
        .slice(0, MAX_BOARDING_CANDIDATES);

      const counts = new Map<string, number>();
      return rows.flatMap((row): PlannerBoarding[] => {
        const stopId = stopIdByKey.get(row.stopKey);
        if (!stopId || row.departureSeconds < (earliestByStop.get(stopId) ?? Infinity)) return [];
        const count = counts.get(stopId) ?? 0;
        if (count >= MAX_BOARDINGS_PER_STOP) return [];
        counts.set(stopId, count + 1);
        return [{
          tripId: row.tripId,
          stopId,
          departureSeconds: row.departureSeconds,
          serviceDate: row.serviceDate,
        }];
      });
    },

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
              tripKey: transitTripStopTimes.tripKey,
              stopId: transitStops.id,
              stopNumericId: transitStops.numericId,
              stopSequence: transitTripStopTimes.stopSequence,
              arrivalSeconds: transitTripStopTimes.arrivalSeconds,
              departureSeconds: transitTripStopTimes.departureSeconds,
              name: transitStops.name,
              coordinate: sql<Coordinate>`json_build_object(
                'latitude', ST_Y(${transitStops.location}),
                'longitude', ST_X(${transitStops.location})
              )`,
            })
            .from(transitTripStopTimes)
            .innerJoin(transitStops, eq(transitStops.numericId, transitTripStopTimes.stopKey))
            .where(inArray(transitTripStopTimes.tripKey, numericIds))
            .orderBy(
              asc(transitTripStopTimes.tripKey),
              asc(transitTripStopTimes.stopSequence)
            )
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

    transfers: async (stopIds) => {
      if (stopIds.length === 0) return [];
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
        })
        .from(transitTransfers)
        .innerJoin(transitStops, eq(transitStops.id, transitTransfers.toStopId))
        .where(inArray(transitTransfers.fromStopId, stopIds));
      return rows.map((row): PlannerTransfer => {
        const toStop = { id: row.toStopId, name: row.name, coordinate: row.coordinate };
        stopCache.set(toStop.id, toStop);
        stopKeyById.set(toStop.id, row.numericId);
        stopIdByKey.set(row.numericId, toStop.id);
        return {
          fromStopId: row.fromStopId,
          toStop,
          minTransferSeconds: row.minTransferSeconds,
        };
      });
    },
  };
}

async function loadBoardingCandidates(
  stopKeys: number[],
  activeServiceIds: string[],
  minimumDepartureSeconds: number,
  serviceDate: string,
  departureOffset: number
): Promise<BoardingCandidate[]> {
  if (activeServiceIds.length === 0) return [];
  const rows = await db
    .select({
      tripId: transitTrips.id,
      stopKey: transitTripStopTimes.stopKey,
      departureSeconds: transitTripStopTimes.departureSeconds,
    })
    .from(transitTripStopTimes)
    .innerJoin(transitTrips, eq(transitTrips.numericId, transitTripStopTimes.tripKey))
    .where(
      and(
        inArray(transitTripStopTimes.stopKey, stopKeys),
        inArray(transitTrips.serviceId, activeServiceIds),
        gte(transitTripStopTimes.departureSeconds, minimumDepartureSeconds)
      )
    )
    .orderBy(asc(transitTripStopTimes.departureSeconds))
    .limit(MAX_BOARDING_CANDIDATES);
  return rows.map((row) => ({
    ...row,
    departureSeconds: row.departureSeconds + departureOffset,
    serviceDate,
  }));
}

function normalizeColor(value: string) {
  return value.startsWith('#') ? value : `#${value}`;
}
