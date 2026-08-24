import { expect, test } from 'bun:test';

import {
  fetchJsonOrNull,
  type PrimRequestEvent,
} from './fetch-json-or-null';

test('a successful PRIM request emits one bounded structured event', async () => {
  const events: PrimRequestEvent[] = [];

  const result = await fetchJsonOrNull(new URL('https://example.test/secret?apikey=hidden'), {
    timeoutMs: 100,
    logLabel: '[test] PRIM',
    telemetry: {
      provider: 'prim',
      product: 'stop_monitoring',
      record: (event) => events.push(event),
    },
    fetcher: async () => new Response(JSON.stringify({ value: 1 }), { status: 200 }),
  });

  expect(result).toEqual({ value: 1 });
  expect(events).toHaveLength(1);
  expect(events[0]).toMatchObject({
    level: 'info',
    provider: 'prim',
    product: 'stop_monitoring',
    outcome: 'success',
    httpStatus: 200,
  });
  expect(events[0]?.durationMs).toBeGreaterThanOrEqual(0);
  expect(JSON.stringify(events[0])).not.toContain('example.test');
});

test('a failed PRIM response reports its status without leaking its body', async () => {
  const events: PrimRequestEvent[] = [];

  const result = await fetchJsonOrNull(new URL('https://example.test/private'), {
    timeoutMs: 100,
    logLabel: '[test] PRIM',
    telemetry: {
      provider: 'prim',
      product: 'disruptions_bulk',
      record: (event) => events.push(event),
    },
    fetcher: async () => new Response('provider-secret-body', { status: 503 }),
  });

  expect(result).toBeNull();
  expect(events).toHaveLength(1);
  expect(events[0]).toMatchObject({
    level: 'error',
    provider: 'prim',
    product: 'disruptions_bulk',
    outcome: 'http_error',
    httpStatus: 503,
  });
  expect(JSON.stringify(events[0])).not.toContain('provider-secret-body');
});
