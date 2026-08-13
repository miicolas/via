import type { JourneysResponse } from '@via/contract';

import { env } from '../../../env';
import { implementer } from '../../../orpc/implementer';
import { redis } from '../../../redis';
import { tryConsumeBudget } from '../../departures/budget';
import { valueThroughCache, journeyCacheKey } from '../cache';
import { tryConsumePersonalJourneyBudget } from '../rate-limit';
import { calculateJourneys } from '../service';

const JOURNEYS_CACHE_CONTROL = 'private, max-age=30';

export const planJourneys = implementer.journeys.plan.handler(
  async ({ input, context, signal }) => {
    context.resHeaders?.set('Cache-Control', JOURNEYS_CACHE_CONTROL);
    const now = new Date();
    const cacheKey = journeyCacheKey({
      origin: input.origin,
      destination: input.destination,
      limit: input.limit,
      now,
    });

    const response = await valueThroughCache<JourneysResponse>(redis, cacheKey, async () => {
      if (!env.API_KEY_PRISM_IDFM) {
        return {
          value: await calculateJourneys(input, now, signal, { realtimeAllowed: false }),
          ttlSeconds: 30,
        };
      }
      const personal = await tryConsumePersonalJourneyBudget(
        redis,
        context.viaIdentity ?? 'anonymous',
        env.PRIM_JOURNEYS_PERSONAL_LIMIT,
        env.PRIM_JOURNEYS_PERSONAL_WINDOW_SECONDS,
        now
      );
      if (!personal.allowed) {
        console.info('[journeys] limite IDFM par personne atteinte, repli GTFS', {
          count: personal.count,
          limit: env.PRIM_JOURNEYS_PERSONAL_LIMIT,
          windowSeconds: env.PRIM_JOURNEYS_PERSONAL_WINDOW_SECONDS,
        });
        return {
          value: await calculateJourneys(input, now, signal, { realtimeAllowed: false }),
          ttlSeconds: 30,
        };
      }

      const budget = await tryConsumeBudget(
        redis,
        env.PRIM_JOURNEYS_DAILY_BUDGET,
        now,
        'journeys'
      );
      if (!budget.allowed) {
        console.info('[journeys] quota IDFM atteinte, repli GTFS', {
          scope: 'journeys',
          ratio: budget.ratio,
        });
        return {
          value: await calculateJourneys(input, now, signal, { realtimeAllowed: false }),
          ttlSeconds: 30,
        };
      }

      return { value: await calculateJourneys(input, now, signal), ttlSeconds: 45 };
    });

    return (
      response ?? {
        status: 'unavailable' as const,
        source: 'gtfs-theoretical' as const,
        generatedAt: now.toISOString(),
        journeys: [],
      }
    );
  }
);
