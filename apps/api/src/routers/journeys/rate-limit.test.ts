import { expect, test } from 'bun:test';

import { fakeRedis } from '../departures/__fixtures__/fake-redis';
import { tryConsumePersonalJourneyBudget } from './rate-limit';

const now = new Date('2026-08-12T10:00:00Z');

test('allows a person inside the configured journey window', async () => {
  const { client } = fakeRedis();
  expect(await tryConsumePersonalJourneyBudget(client, 'person-a', 2, 900, now)).toMatchObject({
    allowed: true,
    count: 1,
  });
  expect(await tryConsumePersonalJourneyBudget(client, 'person-a', 2, 900, now)).toMatchObject({
    allowed: true,
    count: 2,
  });
});

test('switches only the noisy person to GTFS', async () => {
  const { client } = fakeRedis();
  await tryConsumePersonalJourneyBudget(client, 'person-a', 1, 900, now);
  const denied = await tryConsumePersonalJourneyBudget(client, 'person-a', 1, 900, now);
  const other = await tryConsumePersonalJourneyBudget(client, 'person-b', 1, 900, now);

  expect(denied.allowed).toBe(false);
  expect(other.allowed).toBe(true);
});

test('a new window gives the person a fresh allowance', async () => {
  const { client } = fakeRedis();
  await tryConsumePersonalJourneyBudget(client, 'person-a', 1, 900, now);
  const nextWindow = await tryConsumePersonalJourneyBudget(
    client,
    'person-a',
    1,
    900,
    new Date(now.getTime() + 901_000)
  );
  expect(nextWindow.allowed).toBe(true);
  expect(nextWindow.count).toBe(1);
});
