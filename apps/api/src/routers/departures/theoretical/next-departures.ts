import {
  DEPARTURES_PER_GROUP,
  SERVICE_DAY_DEPARTURES_PER_GROUP,
  type DepartureGroup,
  type RouteBadge,
} from '@via/contract';

import { groupDepartures } from '../group-departures';
import { parisDay, previousDate, toInstant } from '../../../time/paris';

/** Enough rows to fill the compact overview at a busy interchange. */
const COMPACT_ROW_LIMIT = 60;

/** A line-specific board can carry every remaining service-day departure. */
export const SERVICE_DAY_ROW_LIMIT = SERVICE_DAY_DEPARTURES_PER_GROUP;

export type TheoreticalDepartureOptions = {
  rowLimit?: number;
  maxDeparturesPerGroup?: number;
};

export type TheoreticalDepartureRow = {
  routeId: string;
  headsign: string;
  departureSeconds: number;
};

type LoadRows = (
  serviceDate: string,
  afterSeconds: number,
  limit: number,
  routeIds: string[]
) => Promise<TheoreticalDepartureRow[]>;

/**
 * Scheduled departures at a stop, as contract groups.
 *
 * Two service days are consulted, not one: at 00:30 the trains still running
 * belong to yesterday's service, recorded as "24:30" — so yesterday is asked
 * for departures past `seconds + 86400`. `loadRows` is injected so the merge
 * logic tests without a database.
 */
export async function nextTheoreticalDepartures(
  now: Date,
  stationRoutes: RouteBadge[],
  loadRows: LoadRows,
  stationId = '',
  lookBehindSeconds = 0,
  options: TheoreticalDepartureOptions = {}
): Promise<DepartureGroup[]> {
  const { date, seconds } = parisDay(now);
  const yesterdayDate = previousDate(date);
  const todayAfterSeconds = Math.max(0, seconds - lookBehindSeconds);
  const yesterdayAfterSeconds = Math.max(0, seconds + 86_400 - lookBehindSeconds);
  const rowLimit = options.rowLimit ?? COMPACT_ROW_LIMIT;
  const routeIds = stationRoutes.map((route) => route.id);

  const [today, yesterday] = await Promise.all([
    loadRows(date, todayAfterSeconds, rowLimit, routeIds),
    loadRows(yesterdayDate, yesterdayAfterSeconds, rowLimit, routeIds),
  ]);

  return groupDepartures(
    [
      ...yesterday.map((row) => ({ row, serviceDate: yesterdayDate })),
      ...today.map((row) => ({ row, serviceDate: date })),
    ].map(({ row, serviceDate }) => ({
      routeId: row.routeId,
      destination: row.headsign,
      scheduledAt: Math.floor(Date.parse(toInstant(serviceDate, row.departureSeconds)) / 1_000),
      status: 'scheduled' as const,
    })),
    stationRoutes,
    stationId,
    options.maxDeparturesPerGroup ?? DEPARTURES_PER_GROUP
  );
}
