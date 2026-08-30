import {
  meetupLiveParticipantSchema,
  type MeetupEncryptedPresence,
  type MeetupLiveParticipant,
  type MeetupProgress,
} from '@via/contract';

const PRESENCE_TTL_SECONDS = 120;
const REVISION_TTL_SECONDS = 8 * 24 * 60 * 60;

export type MeetupLiveRedis = {
  get<T>(key: string): Promise<T | null>;
  set(key: string, value: string, options?: { nx?: boolean; ex?: number }): Promise<string | null>;
  incr(key: string): Promise<number>;
  expire(key: string, seconds: number): Promise<number>;
  del(key: string): Promise<number>;
};

type LiveParticipantSnapshot = {
  participantId: string;
  progress?: MeetupProgress;
  presence?: MeetupEncryptedPresence;
};

type StoredLiveParticipant = LiveParticipantSnapshot & {
  /** Server receipt time. Client timestamps never decide live freshness. */
  receivedAt: string;
  presenceReceivedAt?: string;
};

export type MeetupLiveStore = {
  publish(input: LiveParticipantSnapshot & {
    meetupId: string;
    baseRevision: number;
    clearPresence?: boolean;
  }): Promise<number>;
  read(meetupId: string, participantIds: string[]): Promise<MeetupLiveParticipant[]>;
  revision(meetupId: string, baseRevision: number): Promise<number>;
  bump(meetupId: string, baseRevision: number): Promise<number>;
  clearParticipant(meetupId: string, participantId: string): Promise<void>;
};

export function createMeetupLiveStore(
  redis: MeetupLiveRedis,
  clock: { now: () => Date },
): MeetupLiveStore {
  return {
    async publish({ meetupId, baseRevision, clearPresence = false, ...snapshot }) {
      await ensureRevision(redis, meetupId, baseRevision);
      const key = participantKey(meetupId, snapshot.participantId);
      const previous = await redis.get<StoredLiveParticipant>(key);
      const receivedAt = clock.now();
      const previousPresence = isPresenceCurrent(
        previous?.presence,
        previous?.presenceReceivedAt,
        receivedAt,
      )
        ? previous?.presence
        : undefined;
      const presence = clearPresence
        ? undefined
        : snapshot.presence ?? previousPresence;
      const presenceReceivedAt = clearPresence || presence === undefined
        ? undefined
        : snapshot.presence !== undefined
          ? receivedAt.toISOString()
          : previous?.presenceReceivedAt;
      const merged: StoredLiveParticipant = {
        participantId: snapshot.participantId,
        receivedAt: receivedAt.toISOString(),
        ...(snapshot.progress ?? previous?.progress
          ? { progress: snapshot.progress ?? previous?.progress }
          : {}),
        ...(presence === undefined ? {} : { presence }),
        ...(presenceReceivedAt === undefined ? {} : { presenceReceivedAt }),
      };
      await redis.set(
        key,
        JSON.stringify(merged),
        { ex: PRESENCE_TTL_SECONDS },
      );
      const revision = await redis.incr(revisionKey(meetupId));
      await redis.expire(revisionKey(meetupId), REVISION_TTL_SECONDS);
      return revision;
    },

    async read(meetupId, participantIds) {
      const now = clock.now().getTime();
      return Promise.all(participantIds.map(async (participantId) => {
        const stored = await redis.get<StoredLiveParticipant>(participantKey(meetupId, participantId));
        if (!stored) return { participantId, freshness: 'offline' };
        const updatedAt = serverReceiptTimestamp(stored);
        const ageSeconds = updatedAt === null ? Number.POSITIVE_INFINITY : (now - updatedAt) / 1_000;
        const freshness = ageSeconds <= 20
          ? 'live'
          : ageSeconds <= 60
            ? 'delayed'
            : ageSeconds <= 120
              ? 'stale'
              : 'offline';
        const value = freshness === 'offline'
          ? { participantId, freshness }
          : {
              participantId,
              freshness,
              ...(stored.progress === undefined ? {} : { progress: stored.progress }),
              ...(stored.presence === undefined ? {} : { presence: stored.presence }),
            };
        return meetupLiveParticipantSchema.parse(value);
      }));
    },

    revision(meetupId, baseRevision) {
      return currentRevision(redis, meetupId, baseRevision);
    },

    async bump(meetupId, baseRevision) {
      await ensureRevision(redis, meetupId, baseRevision);
      const revision = await redis.incr(revisionKey(meetupId));
      await redis.expire(revisionKey(meetupId), REVISION_TTL_SECONDS);
      return revision;
    },

    async clearParticipant(meetupId, participantId) {
      await redis.del(participantKey(meetupId, participantId));
    },
  };
}

function isPresenceCurrent(
  presence: MeetupEncryptedPresence | undefined,
  receivedAt: string | undefined,
  now: Date,
): presence is MeetupEncryptedPresence {
  if (!presence || !receivedAt) return false;
  const received = Date.parse(receivedAt);
  const age = now.getTime() - received;
  return Number.isFinite(received) && age >= 0 && age <= PRESENCE_TTL_SECONDS * 1_000;
}

async function ensureRevision(
  redis: MeetupLiveRedis,
  meetupId: string,
  baseRevision: number,
) {
  const key = revisionKey(meetupId);
  await redis.set(key, String(baseRevision), { nx: true, ex: REVISION_TTL_SECONDS });
  const current = await redis.get<number>(key);
  if ((current ?? 0) < baseRevision) {
    await redis.set(key, String(baseRevision), { ex: REVISION_TTL_SECONDS });
  }
}

async function currentRevision(
  redis: MeetupLiveRedis,
  meetupId: string,
  baseRevision: number,
): Promise<number> {
  const current = await redis.get<number>(revisionKey(meetupId));
  return Math.max(baseRevision, current ?? 0);
}

function serverReceiptTimestamp(snapshot: StoredLiveParticipant): number | null {
  const value = Date.parse(snapshot.receivedAt);
  return Number.isFinite(value) ? value : null;
}

function participantKey(meetupId: string, participantId: string) {
  return `meetup:live:${meetupId}:${participantId}`;
}

function revisionKey(meetupId: string) {
  return `meetup:live:${meetupId}:revision`;
}
