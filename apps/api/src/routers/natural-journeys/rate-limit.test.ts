import { expect, test } from 'bun:test';

import { fakeRedis } from '../departures/__fixtures__/fake-redis';
import { consumeNaturalJourneyBudget, isInNaturalJourneyRollout } from './rate-limit';

test('limits AI validations independently per anonymous device', async () => {
  const { client } = fakeRedis();
  const now = new Date('2026-08-14T08:00:00Z');
  const first = await consumeNaturalJourneyBudget(client, 'device-a', 1, 900, now);
  const denied = await consumeNaturalJourneyBudget(client, 'device-a', 1, 900, now);
  const other = await consumeNaturalJourneyBudget(client, 'device-b', 1, 900, now);

  expect(first.allowed).toBe(true);
  expect(denied.allowed).toBe(false);
  expect(other.allowed).toBe(true);
});

test('rollout assignment is stable for one identity', () => {
  expect(isInNaturalJourneyRollout('device-a', 10)).toBe(
    isInNaturalJourneyRollout('device-a', 10)
  );
  expect(isInNaturalJourneyRollout('device-a', 0)).toBe(false);
  expect(isInNaturalJourneyRollout('device-a', 100)).toBe(true);
});
