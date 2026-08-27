import { crowdingSeverity, isDirectJourney, type Journey, type JourneyInput, type JourneyMode, type JourneysResponse } from '@via/contract';

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
import { applyOperationalElevatorConstraint } from './elevators';

type PlannedJourneys = {
  status: 'ready' | 'no-route' | 'unavailable';
  journeys: Journey[];
  reason?: JourneysResponse['reason'];
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
  /** Volatile community state is deliberately applied after the planner cache. */
  reports?: JourneyReportOverlay;
  /** Official network disruptions are volatile and also applied after the planner cache. */
  disruptions?: JourneyDisruptionOverlay;
  /** Enrichment seams stay injectable so planner tests do not need Postgres. */
  annotators?: JourneyPlannerAnnotators;
  /** The default gate is per planner instance, not hidden global state. */
  gtfsPlanGate?: AsyncGate;
};

type AsyncGate = {
  run<T>(work: () => Promise<T>): Promise<T>;
};

export type JourneyPlannerAnnotators = {
  annotateAccessibleJourneys: typeof annotateAccessibleJourneys;
  filterAndAnnotateAccessibleJourneys: typeof filterAndAnnotateAccessibleJourneys;
  annotatePeakJourneys: typeof annotatePeakJourneys;
  annotateWayfinding: typeof annotateWayfinding;
  applyOperationalElevatorConstraint: typeof applyOperationalElevatorConstraint;
};

const defaultJourneyAnnotators: JourneyPlannerAnnotators = {
  annotateAccessibleJourneys,
  filterAndAnnotateAccessibleJourneys,
  annotatePeakJourneys,
  annotateWayfinding,
  applyOperationalElevatorConstraint,
};

export type JourneyReportOverlay = {
  apply(response: JourneysResponse, input: JourneyInput, at: Date): Promise<JourneysResponse>;
};

export type JourneyDisruptionOverlay = JourneyReportOverlay;

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
  reports,
  disruptions,
  annotators = defaultJourneyAnnotators,
  gtfsPlanGate = createAsyncGate(1),
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
        requiresOperationalElevators: input.requiresOperationalElevators,
        originStationId: input.originStationId,
        dayType: parisDayType(requestedAt),
        hour: Math.floor(parisDay(requestedAt).seconds / 3600),
      });

      const gtfsFallback = async () => ({
        value: await planWithGtfsConstraint(
          gtfs,
          input,
          requestedAt,
          now,
          annotators,
          gtfsPlanGate,
          signal
        ),
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

        let realtime = await planWithIdfm(idfm, input, requestedAt, now, annotators, signal);
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
              annotators,
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
                input,
                annotators
              );
            }
          }
        }
        /**
         * IDFM saying "no route" is not the same as there being none. It gives
         * up on an address its street fallback cannot connect to the network,
         * and an empty answer is indistinguishable from a rich one at this
         * seam. Via's own timetable is the second opinion — and until now it
         * was only ever consulted when the call itself failed, so a traveller
         * whose address IDFM would not route from was told that no line
         * connects the two points, without Via ever having looked.
         *
         * The realtime answer still wins whenever it has anything to ride, and
         * it survives an equally empty second opinion so its own reason — no
         * accessible route, no working lift — is the one that reaches the
         * screen.
         */
        const base = realtime?.journeys.length
          ? realtime
          : await secondOpinion(realtime, () =>
              planWithGtfsConstraint(
                gtfs,
                input,
                requestedAt,
                now,
                annotators,
                gtfsPlanGate,
                signal
              ));
        return {
          value: base,
          ttlSeconds: IDFM_TTL_SECONDS,
        };
      };

      const response = await valueThroughCache<JourneysResponse>(redis, cacheKey, async () => {
        const { value, ttlSeconds } = await planned();
        const constrained = await annotators.applyOperationalElevatorConstraint(value, input);
        return {
          value: {
            ...constrained,
            journeys: await annotators.annotateWayfinding(
              constrained.journeys,
              input.destination.coordinate
            ),
          },
          ttlSeconds,
        };
      });

      const stable = response ?? unavailable(now);
      let live = stable;
      if (disruptions) {
        try {
          live = await disruptions.apply(live, input, now);
        } catch (cause) {
          console.error('[journeys] perturbations officielles indisponibles', cause);
        }
      }
      if (reports) {
        try {
          live = await reports.apply(live, input, now);
        } catch (cause) {
          console.error('[journeys] signalements communautaires indisponibles', cause);
        }
      }
      reportPlanWithNothingToRide(live, input);
      return live;
    },
  };
}

/**
 * A plan with nothing to ride is the one outcome nobody could explain after the
 * fact. The screen says the same sentence either way, and the logs only ever
 * named the moment IDFM was skipped — never the answer that came back empty. So
 * a traveller reporting "there is no itinerary from home" left no trace saying
 * whether a live planner found no line, or the timetable fallback — the one
 * that answers once the IDFM quota is spent — could not build the journey.
 *
 * The source is what settles it, so it is what gets written down. Coordinates
 * stay out: the shape of the request explains the outcome, the traveller's
 * doorstep does not.
 */
function reportPlanWithNothingToRide(response: JourneysResponse, input: JourneyInput) {
  if (response.journeys.some((journey) => !isDirectJourney(journey))) return;

  console.info('[journeys] aucun itinéraire en transport', {
    source: response.source,
    status: response.status,
    reason: response.reason,
    destinationKind: input.destination.kind,
    pinnedOrigin: input.originStationId !== undefined,
    requiredModes: input.requiredModes ?? [],
    excludedModes: input.excludedModes ?? [],
    requiresAccessibleStations: input.requiresAccessibleStations ?? false,
    requiresOperationalElevators: input.requiresOperationalElevators ?? false,
  });
}

/**
 * The theoretical plan, kept only when it has something the realtime one did
 * not. An equally empty second opinion changes nothing, so the first answer —
 * and the reason it carries — is what stands.
 */
async function secondOpinion(
  realtime: JourneysResponse | null,
  theoretical: () => Promise<JourneysResponse>
): Promise<JourneysResponse> {
  const answer = await theoretical();
  if (answer.journeys.length === 0) {
    /**
     * The one line that says which safety net gave way. The final log only
     * carries the answer that reached the screen — realtime's, when both are
     * empty — so without this the local timetable's own verdict (found
     * nothing? had no stops to search from? errored into unavailable?) left
     * no trace, and a failing suburb could not be told apart from a broken
     * import.
     */
    console.info('[journeys] second avis GTFS vide', {
      status: answer.status,
      reason: answer.reason,
    });
  }
  return answer.journeys.length > 0 ? answer : realtime ?? answer;
}

async function planWithIdfm(
  idfm: IdfmJourneyPlanner,
  input: JourneyInput,
  requestedAt: Date,
  now: Date,
  annotators: JourneyPlannerAnnotators,
  signal?: AbortSignal
): Promise<JourneysResponse | null> {
  try {
    const response = await idfm.plan(input, requestedAt, signal);
    if (!response) return null;
    if (!input.requiresAccessibleStations) {
      return qualify(response, 'idfm-realtime', now, input, annotators);
    }
    // IDFM has already applied `wheelchair=true`. Missing local rail aliases
    // must not erase a valid, potentially longer bus or tram alternative.
    const journeys = await annotators.annotateAccessibleJourneys(response.journeys);
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
      input,
      annotators
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
  annotators: JourneyPlannerAnnotators,
  signal?: AbortSignal
): Promise<JourneysResponse> {
  try {
    return qualify(
      await gtfs.plan(input, requestedAt, signal),
      'gtfs-theoretical',
      now,
      input,
      annotators
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
  annotators: JourneyPlannerAnnotators,
  gtfsPlanGate: AsyncGate,
  signal?: AbortSignal
) {
  return gtfsPlanGate.run(async () => {
    const response = await planWithGtfs(gtfs, input, requestedAt, now, annotators, signal);
    if (!input.requiresAccessibleStations) return response;
    if (response.status === 'unavailable') return response;
    const journeys = await annotators.filterAndAnnotateAccessibleJourneys(response.journeys);
    return finalizePlan(response, journeys, input);
  });
}

async function qualify(
  response: PlannedJourneys,
  source: NonNullable<JourneysResponse['source']>,
  now: Date,
  input: JourneyInput,
  annotators: JourneyPlannerAnnotators
): Promise<JourneysResponse> {
  const filtered = response.journeys.filter(
    (journey) =>
      matchesModePolicy(journey, input) &&
      (input.datetimeRepresents !== 'arrival' || new Date(journey.departureAt) >= now)
  );
  const annotated = await annotators.annotatePeakJourneys(filtered);
  const journeys = rankPreferredJourney(annotated, input.preferredModes ?? []);
  return {
    ...finalizePlan(response, journeys, input),
    source,
    generatedAt: now.toISOString(),
  };
}

/**
 * The single place a plan's status and reason follow from the journeys that
 * survived filtering — accessibility, mode policy or a community report.
 */
export function finalizePlan<T extends PlannedJourneys>(
  base: T,
  journeys: Journey[],
  input: JourneyInput,
): T {
  return {
    ...base,
    status: journeys.length > 0
      ? 'ready'
      : base.status === 'unavailable' ? 'unavailable' : 'no-route',
    reason: journeys.length === 0 && input.requiresAccessibleStations
      ? 'no-accessible-route'
      : base.reason,
    journeys,
  };
}

function requestedInstant(input: JourneyInput, now: Date) {
  if (!input.requestedAt) return now;
  const instant = new Date(input.requestedAt);
  return Number.isNaN(instant.getTime()) ? now : instant;
}

function matchesModePolicy(journey: Journey, input: JourneyInput) {
  if (isDirectJourney(journey)) {
    const required = input.requiredModes ?? [];
    const hasBike = journey.sections.some((section) => section.type === 'bike');
    return (
      required.length === 0 &&
      (!hasBike || (!input.requiresAccessibleStations && !input.requiresOperationalElevators))
    );
  }

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
  const transit = journeys.filter((journey) => !isDirectJourney(journey));
  const direct = journeys.filter(isDirectJourney);
  if (transit.length === 0) return direct;

  const baseline = transit[0]!;
  const preferred = new Set(preferredModes);
  const ranked = preferredModes.length === 0
    ? [...transit].sort((a, b) => compareJourneyPreference(a, b, preferred))
    : transit;
  const candidate = preferredModes.length === 0
    ? ranked[0]
    : transit
        .filter((journey) => isReasonablePreferred(journey, baseline, preferred))
        .sort((a, b) => compareJourneyPreference(a, b, preferred))[0];

  const rankedTransit = candidate && candidate.id !== baseline.id
    ? promoteJourney(ranked, candidate, baseline)
    : ranked;
  return [...rankedTransit, ...direct];
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

/** Weight per crowding severity, in the scale's own order. */
const CROWDING_PENALTIES = [0, 0.5, 1, 2];

function peakPenalty(journey: Journey) {
  const automatic = journey.peak?.level === 'peak' ? 1 : 0;
  const reported = journey.reportedCrowding?.level;
  const community = reported ? CROWDING_PENALTIES[crowdingSeverity(reported)] ?? 0 : 0;
  return Math.max(automatic, community);
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
