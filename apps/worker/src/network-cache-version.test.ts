import { describe, expect, test } from 'bun:test';

import {
  bumpTransitNetworkCacheVersion,
  type ImportMetaValue,
  TRANSIT_NETWORK_VERSION_KEY,
} from './network-cache-version';

describe('bumpTransitNetworkCacheVersion', () => {
  test('upserts the durable key with the supplied generation', async () => {
    const writes: Array<{ key: string; value: string }> = [];
    const generation = 'generation-1';

    const result = await bumpTransitNetworkCacheVersion({
      upsertImportMeta: async ({ key, value }: ImportMetaValue) => writes.push({ key, value }),
    }, generation);

    expect(result).toBe(generation);
    expect(writes).toEqual([{ key: TRANSIT_NETWORK_VERSION_KEY, value: generation }]);
  });

  test('propagates a durable-store failure', async () => {
    const failure = new Error('database unavailable');

    await expect(bumpTransitNetworkCacheVersion({
      upsertImportMeta: async () => { throw failure; },
    }, 'generation-2')).rejects.toBe(failure);
  });

  test('generates a fresh opaque value for each bump', async () => {
    const store = { upsertImportMeta: async () => undefined };

    const first = await bumpTransitNetworkCacheVersion(store);
    const second = await bumpTransitNetworkCacheVersion(store);

    expect(first).not.toBe(second);
    expect(first).toMatch(/^[0-9a-f-]{36}$/);
    expect(second).toMatch(/^[0-9a-f-]{36}$/);
  });
});
