import { describe, expect, test } from 'bun:test';

import { createTransitNetworkVersionReader } from './network-version';

describe('transit network version reader', () => {
  test('reads once, caches for the local TTL, then refreshes', async () => {
    let clock = 0;
    let reads = 0;
    let value: unknown = 'generation-1';
    const reader = createTransitNetworkVersionReader({
      read: async () => { reads += 1; return value; },
      now: () => clock,
      ttlMs: 60,
    });

    await expect(reader()).resolves.toBe('generation-1');
    clock = 59;
    await expect(reader()).resolves.toBe('generation-1');
    expect(reads).toBe(1);

    value = 'generation-2';
    clock = 60;
    await expect(reader()).resolves.toBe('generation-2');
    expect(reads).toBe(2);
  });

  test('uses the fallback when metadata is absent', async () => {
    const reader = createTransitNetworkVersionReader({ read: async () => null });

    await expect(reader()).resolves.toBe('1');
  });

  test('keeps a stale value and throttles reads when PostgreSQL is unavailable', async () => {
    let clock = 0;
    let reads = 0;
    let unavailableEvents = 0;
    const reader = createTransitNetworkVersionReader({
      read: async () => {
        reads += 1;
        if (reads > 1) throw new Error('database unavailable');
        return 'generation-1';
      },
      now: () => clock,
      ttlMs: 60,
      onUnavailable: () => { unavailableEvents += 1; },
    });

    await expect(reader()).resolves.toBe('generation-1');
    clock = 60;
    await expect(reader()).resolves.toBe('generation-1');
    clock = 61;
    await expect(reader()).resolves.toBe('generation-1');
    expect(reads).toBe(2);
    expect(unavailableEvents).toBe(1);
  });

  test('falls back and caches when there is no known value and the read fails', async () => {
    let clock = 0;
    let reads = 0;
    const reader = createTransitNetworkVersionReader({
      read: async () => { reads += 1; throw new Error('database unavailable'); },
      now: () => clock,
      ttlMs: 60,
    });

    await expect(reader()).resolves.toBe('1');
    clock = 30;
    await expect(reader()).resolves.toBe('1');
    expect(reads).toBe(1);
  });
});
