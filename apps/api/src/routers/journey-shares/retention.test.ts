import { expect, test } from 'bun:test';

import {
  JOURNEY_SHARE_RETENTION_BATCH_SIZE,
  JOURNEY_SHARE_RETENTION_GRACE_MS,
  journeyShareRetentionCutoff,
  runJourneyShareRetentionCycle,
  type JourneyShareRetentionRepository,
} from './retention';

const now = new Date('2026-08-29T12:34:56.000Z');

function fakeRepository(
  result: number | Error = 3,
): JourneyShareRetentionRepository & {
  calls: Array<{ before: Date; limit: number }>;
} {
  const calls: Array<{ before: Date; limit: number }> = [];
  return {
    calls,
    async deleteExpired(before, limit) {
      calls.push({ before, limit });
      if (result instanceof Error) throw result;
      return result;
    },
  };
}

test('uses an exact seven-day retention grace period', () => {
  expect(journeyShareRetentionCutoff(now).getTime()).toBe(
    now.getTime() - JOURNEY_SHARE_RETENTION_GRACE_MS,
  );
  expect(journeyShareRetentionCutoff(now).toISOString()).toBe(
    '2026-08-22T12:34:56.000Z',
  );
});

test('an elected cycle invokes one bounded repository pass', async () => {
  const repository = fakeRepository(500);
  const setCalls: unknown[] = [];
  const count = await runJourneyShareRetentionCycle({
    now,
    repository,
    redisClient: {
      async set(...args) {
        setCalls.push(args);
        return 'OK';
      },
    },
  });

  expect(count).toBe(500);
  expect(repository.calls).toHaveLength(1);
  expect(repository.calls[0]?.limit).toBe(JOURNEY_SHARE_RETENTION_BATCH_SIZE);
  expect(repository.calls[0]?.before.toISOString()).toBe(
    '2026-08-22T12:34:56.000Z',
  );
  expect(setCalls).toHaveLength(1);
});

test('a cycle lost in Redis election does not touch the repository', async () => {
  const repository = fakeRepository();
  const count = await runJourneyShareRetentionCycle({
    now,
    repository,
    redisClient: { async set() { return null; } },
  });

  expect(count).toBe(0);
  expect(repository.calls).toHaveLength(0);
});

test('repository failures propagate through the testable cycle without a timer', async () => {
  const failure = new Error('repository unavailable');
  const repository = fakeRepository(failure);

  await expect(
    runJourneyShareRetentionCycle({
      now,
      repository,
      redisClient: { async set() { return 'OK'; } },
    }),
  ).rejects.toBe(failure);
});
