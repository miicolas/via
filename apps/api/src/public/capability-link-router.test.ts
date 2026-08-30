import { expect, test } from 'bun:test';
import * as z from 'zod';

import { capabilityLinkRouter } from './capability-link-router';

class FakeServiceError extends Error {
  constructor(readonly reason: string) {
    super(`Lookup failed: ${reason}`);
  }
}

function testRouter(load: (token: string) => Promise<{ value: string }>) {
  return capabilityLinkRouter({
    tokenSchema: z.string().length(5),
    load,
    project: (loaded) => ({ projected: loaded.value }),
    isServiceError: (error): error is FakeServiceError => error instanceof FakeServiceError,
    errors: {
      not_found: { code: 'link_not_found', message: 'Introuvable.' },
      revoked: { code: 'link_revoked', message: 'Retiré.' },
      expired: { code: 'link_expired', message: 'Expiré.' },
      corrupt: { code: 'link_unavailable', message: 'Indisponible.' },
    },
    cacheControl: 'public, max-age=30',
  });
}

test('a valid token answers the projection with the cache header', async () => {
  const router = testRouter(async (token) => ({ value: token }));
  const response = await router.request('/aaaaa');

  expect(response.status).toBe(200);
  expect(response.headers.get('Cache-Control')).toBe('public, max-age=30');
  expect(await response.json()).toEqual({ projected: 'aaaaa' });
});

test('a token the schema rejects is a 404 before the service runs', async () => {
  const router = testRouter(async () => {
    throw new Error('must not be reached');
  });
  const response = await router.request('/too-long-token');

  expect(response.status).toBe(404);
  const body = (await response.json()) as { error: { code: string } };
  expect(body.error.code).toBe('link_not_found');
});

test('one status table answers every service reason', async () => {
  const cases = [
    { reason: 'not_found', status: 404, code: 'link_not_found' },
    { reason: 'revoked', status: 404, code: 'link_revoked' },
    { reason: 'expired', status: 410, code: 'link_expired' },
    { reason: 'corrupt', status: 503, code: 'link_unavailable' },
    // A reason the table never anticipated reveals nothing.
    { reason: 'forbidden', status: 404, code: 'link_not_found' },
  ] as const;

  for (const { reason, status, code } of cases) {
    const router = testRouter(async () => {
      throw new FakeServiceError(reason);
    });
    const response = await router.request('/aaaaa');

    expect(response.status).toBe(status);
    expect(response.headers.get('Cache-Control')).toBeNull();
    const body = (await response.json()) as { error: { code: string } };
    expect(body.error.code).toBe(code);
  }
});

test('an error that is not the service error re-throws', async () => {
  const router = testRouter(async () => {
    throw new Error('database gone');
  });
  router.onError((error, c) => c.json({ escaped: error.message }, 500));
  const response = await router.request('/aaaaa');

  expect(response.status).toBe(500);
  expect(await response.json()).toEqual({ escaped: 'database gone' });
});
