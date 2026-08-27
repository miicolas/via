import type { TheoreticalDepartureRow } from './next-departures';
import { selectNextTheoreticalDepartures } from './queries';

/**
 * The database-backed `loadRows` that `nextTheoreticalDepartures` injects.
 * Split out so the merge logic stays testable without a connection.
 */
export function theoreticalRowLoader(stationId: string) {
  return (
    serviceDate: string,
    afterSeconds: number,
    limit: number,
    routeIds: string[] = []
  ): Promise<TheoreticalDepartureRow[]> =>
    selectNextTheoreticalDepartures(stationId, serviceDate, afterSeconds, limit, routeIds);
}
