import { ORPCError } from '@orpc/server';
import type { RouteBadge } from '@via/contract';

import { env } from '../../../env';
import { implementer } from '../../../orpc/implementer';
import { redis } from '../../../redis';
import { parisDay, parisDayType } from '../../../time/paris';
import { adaptiveTtlSeconds } from '../adaptive-ttl';
import { tryConsumeBudget } from '../budget';
import { stationSnapshotThroughCache } from '../cache';
import { toDepartureGroups } from '../mappers';
import { transitNetworkCacheVersion, transitStationSnapshotCacheKey } from '../network-version';
import { fetchStopMonitoring } from '../prim/client';
import { parseStopMonitoring } from '../prim/parse';
import { toMonitoringRef } from '../prim/refs';
import { toRouteBadge } from '../../route-badge';
import { selectStationRoutes } from '../queries';
import { theoreticalRowLoader } from '../theoretical/load-rows';
import { nextTheoreticalDepartures } from '../theoretical/next-departures';
import { stationPeaks } from '../../station-peak';
import { elevatorSnapshotForStation } from '../../elevators';

/**
 * The route is authenticated, so only the device cache may reuse the payload.
 * 30 s stays well under the Redis TTL — the governor upstream, not this header,
 * is what protects the PRIM quota.
 */
const DEPARTURES_CACHE_CONTROL = 'private, max-age=30';
const BASELINE_LOOK_BEHIND_SECONDS = 15 * 60;

export const getStationDepartures = implementer.departures.forStation.handler(
  async ({ input, context, signal }) => {
    const networkVersion = await transitNetworkCacheVersion(redis);
    const cacheKey = transitStationSnapshotCacheKey(networkVersion, input.stationId);
    let fallbackRoutes: RouteBadge[] | undefined;
    const loadRoutes = async () => {
      const routes = (await selectStationRoutes(input.stationId)).map(toRouteBadge);
      fallbackRoutes = routes;
      return routes;
    };

    const snapshot = await stationSnapshotThroughCache(redis, cacheKey, async () => {
      const routes = await loadRoutes();
      if (routes.length === 0) return null;

      const budget = await tryConsumeBudget(redis, env.PRIM_DAILY_BUDGET, new Date());
      if (!budget.allowed) return null;

      const body = await fetchStopMonitoring(
        toMonitoringRef(input.stationId),
        signal
      );
      if (body === null) return null;

      return {
        routes,
        visits: parseStopMonitoring(body),
        fetchedAt: Math.floor(Date.now() / 1_000),
        ttlSeconds: adaptiveTtlSeconds(budget.ratio),
      };
    });

    const routes = snapshot?.routes ?? fallbackRoutes ?? (await loadRoutes());
    if (routes.length === 0) throw new ORPCError('NOT_FOUND');

    context.resHeaders?.set('Cache-Control', DEPARTURES_CACHE_CONTROL);

    const now = new Date();
    const [peak, elevators] = await Promise.all([
      stationPeaks(
        [input.stationId],
        parisDayType(now),
        Math.floor(parisDay(now).seconds / 3600)
      ).then((values) => values.get(input.stationId)),
      elevatorSnapshotForStation(input.stationId),
    ]);

    if (snapshot !== null) {
      let theoreticalBaseline: Awaited<ReturnType<typeof nextTheoreticalDepartures>> = [];
      try {
        theoreticalBaseline = await nextTheoreticalDepartures(
          now,
          routes,
          theoreticalRowLoader(input.stationId),
          input.stationId,
          BASELINE_LOOK_BEHIND_SECONDS
        );
      } catch (cause) {
        // The GTFS baseline enriches realtime but must not take live data down
        // when the schedule database is temporarily unavailable.
        console.error('[departures] GTFS baseline indisponible', cause);
      }

      const groups = toDepartureGroups(
        snapshot.visits,
        routes,
        now,
        input.stationId,
        theoreticalBaseline
      );
      // PRIM answering with nothing is not proof of a quiet station: the stop
      // may sit outside the realtime perimeter. Falling through to the
      // schedule costs one indexed query and tells the difference — if the
      // line really is done for the night, the schedule is empty too.
      if (groups.length > 0) {
        return {
          source: 'realtime' as const,
          generatedAt: now.toISOString(),
          fetchedAt: new Date(snapshot.fetchedAt * 1_000).toISOString(),
          peak,
          elevators,
          groups,
        };
      }
    }

    const scheduled = await nextTheoreticalDepartures(
      now,
      routes,
      theoreticalRowLoader(input.stationId),
      input.stationId
    );

    return {
      source: scheduled.length > 0 ? ('theoretical' as const) : ('unavailable' as const),
      generatedAt: now.toISOString(),
      peak,
      elevators,
      groups: scheduled,
    };
  }
);
