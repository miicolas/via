import type { Journey, JourneyInput, JourneysResponse } from '@via/contract';

import type { RedisClient } from '../../redis';
import { tryConsumeDailyIdfmBudget } from '../idfm/daily-budget';
import { journeyCacheKey, valueThroughCache } from './cache';
import { tryConsumePersonalJourneyBudget } from './rate-limit';

type PlannedJourneys = {
  status: 'ready' | 'no-route' | 'unavailable';
  journeys: Journey[];
};

export type IdfmJourneyPlanner = {
  plan: (
    input: JourneyInput,
    now: Date,
    signal?: AbortSignal
  ) => Promise<PlannedJourneys | null>;
};

export type GtfsJourneyPlanner = {
  plan: (input: JourneyInput, now: Date, signal?: AbortSignal) => Promise<PlannedJourneys>;
};

/** GTFS answers change with the timetable minute; IDFM ones track realtime a bit longer. */
const GTFS_TTL_SECONDS = 30;
const IDFM_TTL_SECONDS = 45;

export type JourneyPlanningConfig = {
  personalLimit: number;
  personalWindowSeconds: number;
  dailyBudget: number;
};

type JourneyPlannerDependencies = {
  redis: RedisClient;
  /** Null is the explicit production adapter when no IDFM key is configured. */
  idfm: IdfmJourneyPlanner | null;
  gtfs: GtfsJourneyPlanner;
  clock: { now: () => Date };
  config: JourneyPlanningConfig;
};

type PlanContext = {
  identity: string;
  signal?: AbortSignal;
};

export type JourneyPlanner = {
  plan: (input: JourneyInput, context: PlanContext) => Promise<JourneysResponse>;
};

/**
 * The deep journey-planning module. Callers provide a request identity and an
 * optional cancellation signal; cache coordination, quotas, source choice,
 * TTLs and fallback qualification remain inside its implementation.
 */
export function createJourneyPlanner({
  redis,
  idfm,
  gtfs,
  clock,
  config,
}: JourneyPlannerDependencies): JourneyPlanner {
  return {
    plan: async (input, { identity, signal }) => {
      const now = clock.now();
      const cacheKey = journeyCacheKey({
        origin: input.origin,
        destination: input.destination,
        limit: input.limit,
        now,
      });

      const gtfsFallback = async () => ({
        value: await planWithGtfs(gtfs, input, now, signal),
        ttlSeconds: GTFS_TTL_SECONDS,
      });

      const response = await valueThroughCache<JourneysResponse>(redis, cacheKey, async () => {
        if (!idfm) return gtfsFallback();

        const personal = await tryConsumePersonalJourneyBudget(
          redis,
          identity,
          config.personalLimit,
          config.personalWindowSeconds,
          now
        );
        if (!personal.allowed) {
          console.info('[journeys] limite IDFM par personne atteinte, repli GTFS', {
            count: personal.count,
            limit: config.personalLimit,
            windowSeconds: config.personalWindowSeconds,
          });
          return gtfsFallback();
        }

        const budget = await tryConsumeDailyIdfmBudget(redis, {
          dailyBudget: config.dailyBudget,
          now,
          counterKeyPrefix: 'prim:budget:journeys',
        });
        if (!budget.allowed) {
          console.info('[journeys] quota IDFM atteint, repli GTFS', {
            ratio: budget.ratio,
          });
          return gtfsFallback();
        }

        const realtime = await planWithIdfm(idfm, input, now, signal);
        return {
          value: realtime ?? (await planWithGtfs(gtfs, input, now, signal)),
          ttlSeconds: IDFM_TTL_SECONDS,
        };
      });

      return response ?? unavailable(now);
    },
  };
}

async function planWithIdfm(
  idfm: IdfmJourneyPlanner,
  input: JourneyInput,
  now: Date,
  signal?: AbortSignal
): Promise<JourneysResponse | null> {
  try {
    const response = await idfm.plan(input, now, signal);
    return response ? qualify(response, 'idfm-realtime', now) : null;
  } catch (cause) {
    console.error('[journeys] planificateur IDFM indisponible', cause);
    return null;
  }
}

async function planWithGtfs(
  gtfs: GtfsJourneyPlanner,
  input: JourneyInput,
  now: Date,
  signal?: AbortSignal
): Promise<JourneysResponse> {
  try {
    return qualify(await gtfs.plan(input, now, signal), 'gtfs-theoretical', now);
  } catch (cause) {
    console.error('[journeys] planificateur GTFS indisponible', cause);
    return unavailable(now);
  }
}

function qualify(
  response: PlannedJourneys,
  source: NonNullable<JourneysResponse['source']>,
  now: Date
): JourneysResponse {
  return { ...response, source, generatedAt: now.toISOString() };
}

function unavailable(now: Date): JourneysResponse {
  return {
    status: 'unavailable',
    source: 'gtfs-theoretical',
    generatedAt: now.toISOString(),
    journeys: [],
  };
}
