import { expect, test } from 'bun:test';

import { createNativeChatHandler } from './handler';

test('native chat reports unavailable when the model is not configured', async () => {
  const handler = createNativeChatHandler(dependencies());

  const response = await handler(
    new Request('http://localhost/ai/chat/v1', {
      method: 'POST',
      body: JSON.stringify({ messages: [{ role: 'user', content: 'Bonjour' }] }),
      headers: { 'Content-Type': 'application/json' },
    }),
    'test-device'
  );

  expect(response.status).toBe(503);
  expect(await response.json()).toEqual({ error: 'chat_unavailable' });
});

test('native chat rejects web-only message shapes before opening a model stream', async () => {
  const handler = createNativeChatHandler(dependencies('test-key'));

  const response = await handler(
    new Request('http://localhost/ai/chat/v1', {
      method: 'POST',
      body: JSON.stringify({
        messages: [{ role: 'system', content: 'must not be forwarded' }],
      }),
      headers: { 'Content-Type': 'application/json' },
    }),
    'test-device'
  );

  expect(response.status).toBe(400);
  expect(await response.json()).toEqual({ error: 'invalid_body' });
});

function dependencies(apiKey?: string) {
  return {
    redis: {
      get: async () => null,
      set: async () => 'OK' as const,
      incr: async () => 1,
      expire: async () => 1,
    },
    places: {
      resolve: async () => {
        throw new Error('not reached');
      },
    },
    journeys: {
      plan: async () => {
        throw new Error('not reached');
      },
    },
    config: {
      apiKey,
      model: 'test-model',
      personalLimit: 20,
      personalWindowSeconds: 900,
    },
  };
}
