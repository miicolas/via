import { expect, test } from 'bun:test';

import { createMeetupLiveStore, type MeetupLiveRedis } from './live-store';

class FakeRedis implements MeetupLiveRedis {
  readonly values = new Map<string, string>();

  async get<T>(key: string): Promise<T | null> {
    const value = this.values.get(key);
    return value === undefined ? null : JSON.parse(value) as T;
  }

  async set(key: string, value: string, options?: { nx?: boolean; ex?: number }) {
    if (options?.nx && this.values.has(key)) return null;
    this.values.set(key, value);
    return 'OK';
  }

  async incr(key: string) {
    const next = Number(this.values.get(key) ?? '0') + 1;
    this.values.set(key, String(next));
    return next;
  }

  async expire() { return 1; }
  async del(key: string) { return this.values.delete(key) ? 1 : 0; }
}

test('live rendez-vous state keeps only the latest encrypted presence', async () => {
  const redis = new FakeRedis();
  let now = new Date('2026-08-30T18:25:00+02:00');
  const store = createMeetupLiveStore(redis, { now: () => now });
  const meetupId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const participantId = '11111111-1111-4111-8111-111111111111';

  const revision = await store.publish({
    meetupId,
    participantId,
    baseRevision: 4,
    progress: {
      status: 'underway',
      serviceId: 'service:a',
      updatedAt: now.toISOString(),
    },
    presence: {
      keyRevision: 1,
      ciphertext: 'encrypted-payload-one',
      sentAt: now.toISOString(),
    },
  });

  expect(revision).toBe(5);
  expect((await store.read(meetupId, [participantId]))[0]?.freshness).toBe('live');

  now = new Date('2026-08-30T18:26:10+02:00');
  expect((await store.read(meetupId, [participantId]))[0]?.freshness).toBe('stale');

  await store.clearParticipant(meetupId, participantId);
  expect((await store.read(meetupId, [participantId]))[0]).toEqual({
    participantId,
    freshness: 'offline',
  });
});

test('a progress heartbeat does not erase the last encrypted presence', async () => {
  const redis = new FakeRedis();
  let now = new Date('2026-08-30T18:25:00+02:00');
  const store = createMeetupLiveStore(redis, { now: () => now });
  const meetupId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const participantId = '11111111-1111-4111-8111-111111111111';

  await store.publish({
    meetupId,
    participantId,
    baseRevision: 0,
    presence: {
      keyRevision: 2,
      ciphertext: 'encrypted-payload-one',
      sentAt: now.toISOString(),
    },
  });
  await store.publish({
    meetupId,
    participantId,
    baseRevision: 0,
    progress: { status: 'underway', updatedAt: now.toISOString() },
  });

  expect((await store.read(meetupId, [participantId]))[0]?.presence?.ciphertext)
    .toBe('encrypted-payload-one');

  now = new Date('2026-08-30T18:27:01+02:00');
  await store.publish({
    meetupId,
    participantId,
    baseRevision: 0,
    progress: { status: 'underway', updatedAt: now.toISOString() },
  });

  const afterExpiry = (await store.read(meetupId, [participantId]))[0];
  expect(afterExpiry?.freshness).toBe('live');
  expect(afterExpiry?.progress?.status).toBe('underway');
  expect(afterExpiry?.presence).toBeUndefined();
});

test('an explicit stop clears precise presence without erasing progression', async () => {
  const redis = new FakeRedis();
  const now = new Date('2026-08-30T18:25:00+02:00');
  const store = createMeetupLiveStore(redis, { now: () => now });
  const meetupId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const participantId = '11111111-1111-4111-8111-111111111111';

  await store.publish({
    meetupId,
    participantId,
    baseRevision: 0,
    progress: { status: 'underway', updatedAt: now.toISOString() },
    presence: {
      keyRevision: 2,
      ciphertext: 'encrypted-payload-one',
      sentAt: now.toISOString(),
    },
  });
  await store.publish({
    meetupId,
    participantId,
    baseRevision: 0,
    clearPresence: true,
    progress: { status: 'stopped', updatedAt: now.toISOString() },
  });

  const stopped = (await store.read(meetupId, [participantId]))[0];
  expect(stopped?.progress?.status).toBe('stopped');
  expect(stopped?.presence).toBeUndefined();
});

test('client timestamps cannot keep a presence fresh or alive', async () => {
  const redis = new FakeRedis();
  let now = new Date('2026-08-30T18:25:00+02:00');
  const store = createMeetupLiveStore(redis, { now: () => now });
  const meetupId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const participantId = '11111111-1111-4111-8111-111111111111';
  const forgedFuture = new Date(now.getTime() + 24 * 60 * 60 * 1_000).toISOString();

  await store.publish({
    meetupId,
    participantId,
    baseRevision: 0,
    progress: { status: 'underway', updatedAt: forgedFuture },
    presence: {
      keyRevision: 2,
      ciphertext: 'encrypted-future-payload',
      sentAt: forgedFuture,
    },
  });

  now = new Date('2026-08-30T18:26:01+02:00');
  expect((await store.read(meetupId, [participantId]))[0]?.freshness).toBe('stale');

  now = new Date('2026-08-30T18:27:01+02:00');
  await store.publish({
    meetupId,
    participantId,
    baseRevision: 0,
    progress: { status: 'underway', updatedAt: forgedFuture },
  });

  const afterServerExpiry = (await store.read(meetupId, [participantId]))[0];
  expect(afterServerExpiry?.freshness).toBe('live');
  expect(afterServerExpiry?.presence).toBeUndefined();
});
