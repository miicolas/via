import { ORPCError } from '@orpc/server';

import { env } from '../../../env';
import { implementer } from '../../../orpc/implementer';
import { redis } from '../../../redis';
import { adaptiveTtlSeconds } from '../adaptive-ttl';
import { tryConsumeBudget } from '../budget';
import { visitsThroughCache } from '../cache';
import { toDepartureGroups } from '../mappers';
import { fetchStopMonitoring } from '../prim/client';
import { parseStopMonitoring } from '../prim/parse';
import { toMonitoringRef } from '../prim/refs';
import { toRouteBadge } from '../../route-badge';
import { selectStationRoutes } from '../queries';
import { theoreticalRowLoader } from '../theoretical/load-rows';
import { nextTheoreticalDepartures } from '../theoretical/next-departures';

/**
 * The route is authenticated, so only the device cache may reuse the payload.
 * 30 s stays well under the Redis TTL — the governor upstream, not this header,
 * is what protects the PRIM quota.
 */
const DEPARTURES_CACHE_CONTROL = 'private, max-age=30';

export const getStationDepartures = implementer.departures.forStation.handler(
  async ({ input, context, signal }) => {
    const routes = (await selectStationRoutes(input.stationId)).map(toRouteBadge);
    if (routes.length === 0) throw new ORPCError('NOT_FOUND');

    context.resHeaders?.set('Cache-Control', DEPARTURES_CACHE_CONTROL);

    const now = new Date();
    const visits = await visitsThroughCache(redis, `stop:${input.stationId}`, async () => {
      const budget = await tryConsumeBudget(redis, env.PRIM_DAILY_BUDGET, now);
      if (!budget.allowed) return null;

      const body = await fetchStopMonitoring(toMonitoringRef(input.stationId), signal);
      if (body === null) return null;

      return {
        visits: parseStopMonitoring(body),
        ttlSeconds: adaptiveTtlSeconds(budget.ratio),
      };
    });

    if (visits !== null) {
      const groups = toDepartureGroups(visits, routes, now);
      // PRIM answering with nothing is not proof of a quiet station: the stop
      // may sit outside the realtime perimeter. Falling through to the
      // schedule costs one indexed query and tells the difference — if the
      // line really is done for the night, the schedule is empty too.
      if (groups.length > 0) {
        return { source: 'realtime' as const, generatedAt: now.toISOString(), groups };
      }
    }

    const scheduled = await nextTheoreticalDepartures(
      now,
      routes,
      theoreticalRowLoader(input.stationId)
    );

    return {
      source: scheduled.length > 0 ? ('theoretical' as const) : ('unavailable' as const),
      generatedAt: now.toISOString(),
      groups: scheduled,
    };
  }
);
