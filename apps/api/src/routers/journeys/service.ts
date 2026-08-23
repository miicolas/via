import type { Journey, JourneyInput, JourneyMode, JourneysResponse } from '@via/contract';

import type { RedisClient } from '../../redis';
import { parisDay, parisDayType } from '../../time/paris';
import { tryConsumeDailyIdfmBudget } from '../idfm/daily-budget';
import { journeyCacheKey, valueThroughCache } from './cache';
import { tryConsumePersonalJourneyBudget } from './rate-limit';
import { createAsyncGate } from './gtfs/concurrency';
import {
  annotateAccessibleJourneys,
  filterAndAnnotateAccessibleJourneys,
} from './accessibility';
import { annotatePeakJourneys } from './peak';
import { annotateWayfinding } from './wayfinding';

type PlannedJourneys = {
  status: 'ready' | 'no-route' | 'unavailable';
  journeys: Journey[];
  reason?: 'no-accessible-route' | 'accessibility-data-unavailable';
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
/** Keep Postgres dynamic shared-memory use bounded during the GTFS fallback. */
const gtfsPlanGate = createAsyncGate(1);

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
      const requestedAt = requestedInstant(input, now);
      const cacheKey = journeyCacheKey({
        origin: input.origin,
        destination: input.destination,
        limit: input.limit,
        requestedAt,
        datetimeRepresents: input.datetimeRepresents,
        requiredModes: input.requiredModes,
        excludedModes: input.excludedModes,
        preferredModes: input.preferredModes,
        requiresAccessibleStations: input.requiresAccessibleStations,
        originStationId: input.originStationId,
        dayType: parisDayType(requestedAt),
        hour: Math.floor(parisDay(requestedAt).seconds / 3600),
      });

      const gtfsFallback = async () => ({
        value: await planWithGtfsConstraint(gtfs, input, requestedAt, now, signal),
        ttlSeconds: GTFS_TTL_SECONDS,
      });

      /**
       * Wayfinding rides inside the cached value rather than decorating the
       * response afterwards: it is a pure function of the journeys and the
       * destination, and the destination is already part of the cache key, so
       * two callers sharing an entry share the same exit.
       */
      const planned = async () => {
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

        let realtime = await planWithIdfm(idfm, input, requestedAt, now, signal);
        if (
          realtime?.status === 'ready' &&
          input.preferredModes?.length &&
          !hasReasonablePreferred(realtime.journeys, input.preferredModes)
        ) {
          const extraBudget = await tryConsumeDailyIdfmBudget(redis, {
            dailyBudget: config.dailyBudget,
            now,
            counterKeyPrefix: 'prim:budget:journeys',
          });
          if (extraBudget.allowed) {
            const preferredOnly = await planWithIdfm(
              idfm,
              {
                ...input,
                requiredModes: input.preferredModes,
                preferredModes: [],
              },
              requestedAt,
              now,
              signal
            );
            if (preferredOnly?.journeys.length) {
              realtime = await qualify(
                {
                  ...realtime,
                  journeys: dedupeJourneys([...realtime.journeys, ...preferredOnly.journeys]),
                },
                'idfm-realtime',
                now,
                input
              );
            }
          }
        }
        return {
          value: realtime ?? (await planWithGtfsConstraint(gtfs, input, requestedAt, now, signal)),
          ttlSeconds: IDFM_TTL_SECONDS,
        };
      };

      const response = await valueThroughCache<JourneysResponse>(redis, cacheKey, async () => {
        const { value, ttlSeconds } = await planned();
        return {
          value: {
            ...value,
            journeys: await annotateWayfinding(value.journeys, input.destination.coordinate),
          },
          ttlSeconds,
        };
      });

      return response ?? unavailable(now);
    },
  };
}

async function planWithIdfm(
  idfm: IdfmJourneyPlanner,
  input: JourneyInput,
  requestedAt: Date,
  now: Date,
  signal?: AbortSignal
): Promise<JourneysResponse | null> {
  try {
    const response = await idfm.plan(input, requestedAt, signal);
    if (!response) return null;
    if (!input.requiresAccessibleStations) return qualify(response, 'idfm-realtime', now, input);
    // IDFM has already applied `wheelchair=true`. Missing local rail aliases
    // must not erase a valid, potentially longer bus or tram alternative.
    const journeys = await annotateAccessibleJourneys(response.journeys);
    const status: PlannedJourneys['status'] = response.status === 'unavailable'
      ? 'unavailable'
      : journeys.length > 0
        ? 'ready'
        : 'no-route';
    return qualify(
      {
        ...response,
        status,
        journeys,
        reason: status === 'no-route' ? 'no-accessible-route' : undefined,
      },
      'idfm-realtime',
      now,
      input
    );
  } catch (cause) {
    console.error('[journeys] planificateur IDFM indisponible', cause);
    return null;
  }
}

async function planWithGtfs(
  gtfs: GtfsJourneyPlanner,
  input: JourneyInput,
  requestedAt: Date,
  now: Date,
  signal?: AbortSignal
): Promise<JourneysResponse> {
  try {
    return qualify(
      await gtfs.plan(input, requestedAt, signal),
      'gtfs-theoretical',
      now,
      input
    );
  } catch (cause) {
    console.error('[journeys] planificateur GTFS indisponible', cause);
    return unavailable(now);
  }
}

async function planWithGtfsConstraint(
  gtfs: GtfsJourneyPlanner,
  input: JourneyInput,
  requestedAt: Date,
  now: Date,
  signal?: AbortSignal
) {
  return gtfsPlanGate.run(async () => {
    const response = await planWithGtfs(gtfs, input, requestedAt, now, signal);
    if (!input.requiresAccessibleStations) return response;
    if (response.status === 'unavailable') return response;
    const journeys = await filterAndAnnotateAccessibleJourneys(response.journeys);
    return {
      ...response,
      status: journeys.length > 0 ? 'ready' as const : 'no-route' as const,
      reason: journeys.length > 0 ? undefined : 'no-accessible-route' as const,
      journeys,
    };
  });
}

async function qualify(
  response: PlannedJourneys,
  source: NonNullable<JourneysResponse['source']>,
  now: Date,
  input: JourneyInput
): Promise<JourneysResponse> {
  const filtered = response.journeys.filter(
    (journey) =>
      matchesModePolicy(journey, input) &&
      (input.datetimeRepresents !== 'arrival' || new Date(journey.departureAt) >= now)
  );
  const annotated = await annotatePeakJourneys(filtered);
  const journeys = rankPreferredJourney(annotated, input.preferredModes ?? []);
  return {
    ...response,
    status: journeys.length > 0 ? 'ready' : response.status === 'unavailable' ? 'unavailable' : 'no-route',
    journeys,
    source,
    generatedAt: now.toISOString(),
  };
}

function requestedInstant(input: JourneyInput, now: Date) {
  if (!input.requestedAt) return now;
  const instant = new Date(input.requestedAt);
  return Number.isNaN(instant.getTime()) ? now : instant;
}

function matchesModePolicy(journey: Journey, input: JourneyInput) {
  const modes = journey.sections.flatMap((section) =>
    section.type === 'transit' && section.route ? [section.route.mode] : []
  );
  if (modes.length === 0) return false;
  const required = input.requiredModes ?? [];
  const excluded = new Set(input.excludedModes ?? []);
  return (
    modes.every((mode) => !excluded.has(mode)) &&
    (required.length === 0 || modes.every((mode) => required.includes(mode)))
  );
}

export function rankPreferredJourney(journeys: Journey[], preferredModes: JourneyMode[]) {
  const baseline = journeys[0];
  if (!baseline) return journeys;
  const preferred = new Set(preferredModes);
  if (preferredModes.length === 0) {
    const ranked = [...journeys].sort((a, b) => compareJourneyPreference(a, b, preferred));
    const candidate = ranked[0];
    return candidate && candidate.id !== baseline.id
      ? promoteJourney(ranked, candidate, baseline)
      : ranked;
  }
  const candidate = journeys
    .filter((journey) => isReasonablePreferred(journey, baseline, preferred))
    .sort((a, b) => compareJourneyPreference(a, b, preferred))[0];
  if (!candidate || candidate.id === baseline.id) return journeys;
  return promoteJourney(journeys, candidate, baseline);
}

function promoteJourney(journeys: Journey[], candidate: Journey, baseline: Journey) {
  return [
    { ...candidate, qualifier: 'recommended' as const },
    ...journeys
      .filter((journey) => journey.id !== candidate.id)
      .map((journey) =>
        journey.id === baseline.id && journey.qualifier === 'recommended'
          ? { ...journey, qualifier: 'rapid' as const }
          : journey
      ),
  ];
}

/**
 * A peak is only a tie-breaker. A calm transfer can move ahead inside a
 * three-minute duration band, but a genuinely faster journey always wins.
 */
function compareJourneyPreference(
  a: Journey,
  b: Journey,
  preferredModes: ReadonlySet<JourneyMode>
) {
  const durationDifference = a.durationSeconds - b.durationSeconds;
  const peakDifference = peakPenalty(a) - peakPenalty(b);
  if (Math.abs(durationDifference) <= 180 && peakDifference !== 0) return peakDifference;
  return durationDifference || preferredShare(b, preferredModes) - preferredShare(a, preferredModes);
}

function peakPenalty(journey: Journey) {
  return journey.peak?.level === 'peak' ? 1 : 0;
}

export function preferredShare(journey: Journey, preferredModes: ReadonlySet<JourneyMode>) {
  let preferredSeconds = 0;
  let transitSeconds = 0;
  for (const section of journey.sections) {
    if (section.type !== 'transit' || !section.route) continue;
    transitSeconds += section.durationSeconds;
    if (preferredModes.has(section.route.mode)) preferredSeconds += section.durationSeconds;
  }
  return transitSeconds > 0 ? preferredSeconds / transitSeconds : 0;
}

function hasReasonablePreferred(journeys: Journey[], preferredModes: JourneyMode[]) {
  const baseline = journeys[0];
  if (!baseline) return false;
  const preferred = new Set(preferredModes);
  return journeys.some((journey) => isReasonablePreferred(journey, baseline, preferred));
}

/**
 * The single definition of an acceptable preferred-mode journey: mostly in a
 * preferred mode, and not meaningfully slower than the fastest baseline.
 */
function isReasonablePreferred(
  journey: Journey,
  baseline: Journey,
  preferred: ReadonlySet<JourneyMode>
) {
  return (
    preferredShare(journey, preferred) > 0.5 &&
    journey.durationSeconds <= baseline.durationSeconds + 15 * 60 &&
    journey.durationSeconds <= baseline.durationSeconds * 1.25
  );
}

function dedupeJourneys(journeys: Journey[]) {
  return [...new Map(journeys.map((journey) => [journey.id, journey])).values()];
}

function unavailable(now: Date, reason?: JourneysResponse['reason']): JourneysResponse {
  return {
    status: 'unavailable',
    source: 'gtfs-theoretical',
    generatedAt: now.toISOString(),
    reason,
    journeys: [],
  };
}
