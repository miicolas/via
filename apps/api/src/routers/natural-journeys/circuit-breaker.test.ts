import { describe, expect, test } from 'bun:test';

import { fakeRedis } from '../departures/__fixtures__/fake-redis';
import { createCircuitBreaker } from './circuit-breaker';

describe('circuit breaker', () => {
  test('opens only after the configured consecutive failures', async () => {
    const { client } = fakeRedis();
    const breaker = createCircuitBreaker(client, { failureThreshold: 3, openSeconds: 60 });

    expect(await breaker.isOpen()).toBe(false);
    await breaker.recordFailure();
    await breaker.recordFailure();
    expect(await breaker.isOpen()).toBe(false);
    await breaker.recordFailure();
    expect(await breaker.isOpen()).toBe(true);
  });

  test('a success resets the failure streak', async () => {
    const { client } = fakeRedis();
    const breaker = createCircuitBreaker(client, { failureThreshold: 3, openSeconds: 60 });

    await breaker.recordFailure();
    await breaker.recordFailure();
    await breaker.recordSuccess();
    await breaker.recordFailure();
    await breaker.recordFailure();

    // Only two failures since the reset — still below the threshold.
    expect(await breaker.isOpen()).toBe(false);
  });

  test('the open window carries the configured TTL', async () => {
    const { client, expiries } = fakeRedis();
    const breaker = createCircuitBreaker(client, { failureThreshold: 1, openSeconds: 60 });

    await breaker.recordFailure();

    expect(await breaker.isOpen()).toBe(true);
    expect(expiries.get('openai:breaker:open')).toBe(60);
  });
});
