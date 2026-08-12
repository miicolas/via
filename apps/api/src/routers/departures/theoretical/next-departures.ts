import type { DepartureGroup } from '@via/contract';

import { groupDepartures } from '../group-departures';
import { parisServiceDay, previousDate, toInstant } from './service-day';

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
  stationRouteIds: string[],
  loadRows: LoadRows
): Promise<DepartureGroup[]> {
  const { date, seconds } = parisServiceDay(now);
  const yesterdayDate = previousDate(date);

  const [today, yesterday] = await Promise.all([
    loadRows(date, seconds, ROW_LIMIT),
    loadRows(yesterdayDate, seconds + 86_400, ROW_LIMIT),
  ]);

  return groupDepartures(
    [
      ...yesterday.map((row) => ({ row, serviceDate: yesterdayDate })),
      ...today.map((row) => ({ row, serviceDate: date })),
    ].map(({ row, serviceDate }) => ({
      routeId: row.routeId,
      destination: row.headsign,
      at: toInstant(serviceDate, row.departureSeconds),
    })),
    stationRouteIds
  );
}
