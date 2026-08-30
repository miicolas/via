import { and, eq, inArray, lte, sql } from 'drizzle-orm';
import {
  jobDb,
  meetupInvitations,
  meetups,
  type MeetupRow,
} from '@via/db';
import { MEETUP_GRACE_MS, meetupPlanSchema } from '@via/contract';

import { redis, type RedisClient } from '../../redis';
import { stalePlan } from './convergence';
import {
  MEETUP_PLANNING_RETRY_MS,
  type MeetupPlanningService,
} from './planning';
import {
  noOpMeetupSemanticNotifier,
  type MeetupSemanticNotifier,
} from './notifier';

export const MEETUP_MAINTENANCE_INTERVAL_MS = 5 * 60 * 1_000;
export const MEETUP_MAINTENANCE_BATCH_SIZE = 100;
const ELECTION_TTL_SECONDS = 6 * 60;

export type MeetupMaintenanceRepository = {
  due(now: Date, limit: number): Promise<Array<{ id: string; targetArrivalAt: Date }>>;
  markStale(meetupId: string, now: Date): Promise<void>;
  expireInvitations(now: Date): Promise<number>;
  expireMeetups(now: Date): Promise<number>;
  purge(now: Date, limit: number): Promise<number>;
};

const databaseRepository: MeetupMaintenanceRepository = {
  async due(now, limit) {
    return jobDb
      .select({ id: meetups.id, targetArrivalAt: meetups.targetArrivalAt })
      .from(meetups)
      .where(and(
        lte(meetups.nextRefreshAt, now),
        inArray(meetups.phase, ['planning', 'ready']),
      ))
      .orderBy(meetups.nextRefreshAt, meetups.id)
      .limit(limit);
  },

  async markStale(meetupId, now) {
    const rows = await jobDb.select().from(meetups).where(eq(meetups.id, meetupId)).limit(1);
    const row = rows[0];
    if (!row) return;
    const previous = safePlan(row);
    await jobDb.update(meetups).set({
      ...(previous
        ? {
            plan: stalePlan(previous, row.revision + 1) as unknown as Record<string, unknown>,
          }
        : {}),
      revision: row.revision + 1,
      nextRefreshAt: new Date(now.getTime() + MEETUP_PLANNING_RETRY_MS),
      updatedAt: now,
    }).where(eq(meetups.id, meetupId));
  },

  async expireInvitations(now) {
    const rows = await jobDb.update(meetupInvitations).set({
      status: 'expired',
      respondedAt: now,
    }).where(and(
      eq(meetupInvitations.status, 'pending'),
      lte(meetupInvitations.expiresAt, now),
    )).returning({ id: meetupInvitations.id });
    return rows.length;
  },

  async expireMeetups(now) {
    const liveDeadline = new Date(now.getTime() - MEETUP_GRACE_MS);
    const rows = await jobDb.update(meetups).set({
      phase: 'expired',
      revision: sql`${meetups.revision} + 1`,
      keyRevision: sql`${meetups.keyRevision} + 1`,
      nextRefreshAt: null,
      updatedAt: now,
    }).where(and(
      inArray(meetups.phase, ['planning', 'ready', 'live']),
      lte(meetups.targetArrivalAt, liveDeadline),
    )).returning({ id: meetups.id });
    return rows.length;
  },

  async purge(now, limit) {
    const candidates = await jobDb
      .select({ id: meetups.id })
      .from(meetups)
      .where(lte(meetups.purgeAt, now))
      .orderBy(meetups.purgeAt, meetups.id)
      .limit(limit);
    if (candidates.length === 0) return 0;
    const rows = await jobDb.delete(meetups)
      .where(inArray(meetups.id, candidates.map(({ id }) => id)))
      .returning({ id: meetups.id });
    return rows.length;
  },
};

function safePlan(row: MeetupRow) {
  const parsed = meetupPlanSchema.safeParse(row.plan);
  return parsed.success ? parsed.data : null;
}

export async function runMeetupMaintenanceCycle({
  planning,
  now = new Date(),
  redisClient = redis,
  repository = databaseRepository,
  notifier = noOpMeetupSemanticNotifier,
}: {
  planning: MeetupPlanningService;
  now?: Date;
  redisClient?: Pick<RedisClient, 'set'>;
  repository?: MeetupMaintenanceRepository;
  notifier?: MeetupSemanticNotifier;
}): Promise<{
  refreshed: number;
  failed: number;
  expired: number;
  meetupsExpired: number;
  purged: number;
}> {
  const cycle = Math.floor(now.getTime() / MEETUP_MAINTENANCE_INTERVAL_MS);
  const elected = await redisClient.set(`meetups:maintenance:${cycle}`, '1', {
    nx: true,
    ex: ELECTION_TTL_SECONDS,
  });
  if (!elected) {
    return { refreshed: 0, failed: 0, expired: 0, meetupsExpired: 0, purged: 0 };
  }

  const due = await repository.due(now, MEETUP_MAINTENANCE_BATCH_SIZE);
  let refreshed = 0;
  let failed = 0;
  for (const meetup of due) {
    try {
      await planning.recompute({
        meetupId: meetup.id,
        identity: `scheduled:${meetup.id}`,
        reason: 'scheduled-refresh',
      });
      refreshed += 1;
      const untilArrival = meetup.targetArrivalAt.getTime() - now.getTime();
      if (untilArrival > 0 && untilArrival <= MEETUP_GRACE_MS + MEETUP_MAINTENANCE_INTERVAL_MS) {
        await notifier.departureSoon(meetup.id).catch(() => {
          console.error('[meetups] departure notification failed');
        });
      }
    } catch {
      failed += 1;
      await repository.markStale(meetup.id, now);
    }
  }

  const [expired, meetupsExpired, purged] = await Promise.all([
    repository.expireInvitations(now),
    repository.expireMeetups(now),
    repository.purge(now, MEETUP_MAINTENANCE_BATCH_SIZE),
  ]);
  return { refreshed, failed, expired, meetupsExpired, purged };
}

let timer: ReturnType<typeof setInterval> | undefined;

export function startMeetupRuntime(
  planning: MeetupPlanningService,
  notifier: MeetupSemanticNotifier = noOpMeetupSemanticNotifier,
): void {
  if (process.env.NODE_ENV === 'test' || timer) return;
  const run = () => {
    void runMeetupMaintenanceCycle({ planning, notifier }).catch(() => {
      console.error('[meetups] maintenance failed');
    });
  };
  run();
  timer = setInterval(run, MEETUP_MAINTENANCE_INTERVAL_MS);
}

export function stopMeetupRuntime(): void {
  if (timer) clearInterval(timer);
  timer = undefined;
}
