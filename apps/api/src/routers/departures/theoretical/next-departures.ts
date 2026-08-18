import type { DepartureGroup, RouteBadge } from '@via/contract';

import { groupDepartures } from '../group-departures';
import { parisDay, previousDate, toInstant } from '../../../time/paris';

/** Enough rows to fill several directions of a busy interchange. */
const ROW_LIMIT = 60;

export type TheoreticalDepartureRow = {
  routeId: string;
  headsign: string;
  departureSeconds: number;
};

type LoadRows = (
  serviceDate: string,
  afterSeconds: number,
  limit: number
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
  lookBehindSeconds = 0
): Promise<DepartureGroup[]> {
  const { date, seconds } = parisDay(now);
  const yesterdayDate = previousDate(date);
  const todayAfterSeconds = Math.max(0, seconds - lookBehindSeconds);
  const yesterdayAfterSeconds = Math.max(0, seconds + 86_400 - lookBehindSeconds);

  const [today, yesterday] = await Promise.all([
    loadRows(date, todayAfterSeconds, ROW_LIMIT),
    loadRows(yesterdayDate, yesterdayAfterSeconds, ROW_LIMIT),
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
    stationId
  );
}
