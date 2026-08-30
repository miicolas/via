import { eq } from 'drizzle-orm';
import {
  MEETUP_GRACE_MS,
  journeyPlanningPolicySchema,
  meetupPlanSchema,
  type JourneyInput,
  type MeetupOrigin,
} from '@via/contract';
import { db, meetupParticipants, meetups } from '@via/db';

import type { JourneyPlanner } from '../journeys/service';
import { meetupDestination } from './aggregate';
import { buildConvergencePlan, stalePlan } from './convergence';
import {
  recordMeetupMetric,
  type MeetupMetric,
  type MeetupPlanAvailability,
  type MeetupReplanReason,
} from './metrics';
import type { MeetupOriginCipher } from './origin-crypto';
import { loadMeetupAggregate } from './store';

export type MeetupPlanningReason = 'creation' | MeetupReplanReason;

export type MeetupPlanningService = {
  recompute(input: {
    meetupId: string;
    identity: string;
    reason: MeetupPlanningReason;
    overrideOrigins?: ReadonlyMap<string, MeetupOrigin>;
  }): Promise<void>;
};

export function createMeetupPlanningService({
  journeyPlanner,
  originCipher,
  clock,
  recordMetric = recordMeetupMetric,
}: {
  journeyPlanner: JourneyPlanner;
  originCipher: MeetupOriginCipher;
  clock: { now: () => Date };
  recordMetric?: (metric: MeetupMetric) => void;
}): MeetupPlanningService {
  return {
    async recompute({ meetupId, identity, reason, overrideOrigins }) {
      const aggregate = await loadMeetupAggregate(meetupId);
      const now = clock.now();
      const destination = meetupDestination(aggregate.meetup);
      const participants = aggregate.activeParticipants();
      const revision = aggregate.meetup.revision + 1;

      const candidateResults = await Promise.all(participants.map(async (participant) => {
        const origin = overrideOrigins?.get(participant.id)
          ?? originCipher.decrypt(participant.encryptedOrigin);
        const policy = journeyPlanningPolicySchema.parse(participant.planningPolicy);
        const request: JourneyInput = {
          origin: origin.coordinate,
          destination: { kind: 'station', ...destination },
          limit: 6,
          requestedAt: aggregate.meetup.targetArrivalAt.toISOString(),
          datetimeRepresents: 'arrival',
          requiredModes: policy.requiredModes,
          excludedModes: policy.excludedModes,
          preferredModes: policy.preferredModes,
          requiresAccessibleStations: policy.requiresAccessibleStations,
          requiresOperationalElevators: policy.requiresOperationalElevators,
          ...(origin.kind === 'station' ? { originStationId: origin.id } : {}),
        };
        try {
          const response = await journeyPlanner.plan(request, {
            identity: `${identity}:${participant.id}`,
          });
          return { participantId: participant.id, journeys: response.journeys, failed: false };
        } catch (cause) {
          console.error('[meetups] calcul individuel indisponible', {
            meetupId,
            participantId: participant.id,
            cause: cause instanceof Error ? cause.name : 'unknown',
          });
          return { participantId: participant.id, journeys: [], failed: true };
        }
      }));
      const candidates = candidateResults.map(({ failed: _failed, ...candidate }) => candidate);

      if (candidateResults.some((candidate) => candidate.failed) && aggregate.meetup.plan) {
        const previous = meetupPlanSchema.parse(aggregate.meetup.plan);
        await db.update(meetups).set({
          plan: stalePlan(previous, revision) as unknown as Record<string, unknown>,
          revision,
          nextRefreshAt: new Date(now.getTime() + MEETUP_PLANNING_RETRY_MS),
          updatedAt: now,
        }).where(eq(meetups.id, meetupId));
        emitPlanningMetrics(recordMetric, reason, 'stale');
        return;
      }

      const plan = buildConvergencePlan({
        participants: candidates,
        destination,
        targetArrivalAt: aggregate.meetup.targetArrivalAt,
        generatedAt: now,
        revision,
      });
      meetupPlanSchema.parse(plan);
      const selected = new Map(
        plan.participantJourneys.map((entry) => [entry.participantId, entry] as const),
      );
      const persistedPlan = {
        ...plan,
        participantJourneys: plan.participantJourneys.map(({ journey: _journey, ...entry }) => entry),
      };
      meetupPlanSchema.parse(persistedPlan);

      await db.transaction(async (tx) => {
        for (const participant of participants) {
          const entry = selected.get(participant.id);
          const fullJourney = entry?.journey;
          await tx
            .update(meetupParticipants)
            .set({
              journey: fullJourney ? originCipher.encryptJourney(fullJourney) : null,
              firstBoardingStation:
                (entry?.firstBoardingStation as Record<string, unknown> | undefined) ?? null,
              departureAt: entry ? new Date(entry.departureAt) : null,
              arrivalAt: entry ? new Date(entry.arrivalAt) : null,
              state:
                participant.state === 'configuring' && fullJourney
                  ? 'ready'
                  : participant.state,
              updatedAt: now,
            })
            .where(eq(meetupParticipants.id, participant.id));
        }
        await tx
          .update(meetups)
          .set({
            plan: persistedPlan as unknown as Record<string, unknown>,
            phase:
              aggregate.meetup.phase === 'live'
                ? 'live'
                : plan.status === 'unavailable'
                  ? 'planning'
                  : 'ready',
            revision,
            nextRefreshAt: nextScheduledRefresh(aggregate.meetup.targetArrivalAt, now),
            updatedAt: now,
          })
          .where(eq(meetups.id, meetupId));
      });
      emitPlanningMetrics(recordMetric, reason, planAvailability(plan.status));
    },
  };
}

function planAvailability(
  status: 'ready' | 'fallbackAtDestination' | 'unavailable',
): MeetupPlanAvailability {
  switch (status) {
  case 'ready': return 'ready';
  case 'fallbackAtDestination': return 'fallback-at-destination';
  case 'unavailable': return 'unavailable';
  }
}

function emitPlanningMetrics(
  recordMetric: (metric: MeetupMetric) => void,
  reason: MeetupPlanningReason,
  category: MeetupPlanAvailability,
): void {
  recordMetric({ event: 'plan-availability', category });
  if (reason !== 'creation') {
    recordMetric({ event: 'replan', reason, category });
  }
}

export function nextScheduledRefresh(target: Date, now: Date): Date | null {
  const dayBefore = new Date(target.getTime() - 24 * 60 * 60 * 1_000);
  if (dayBefore > now) return dayBefore;
  const earliestDeparture = new Date(target.getTime() - MEETUP_GRACE_MS);
  if (earliestDeparture > now) return earliestDeparture;
  return null;
}

export const MEETUP_PLANNING_RETRY_MS = 15 * 60 * 1_000;
